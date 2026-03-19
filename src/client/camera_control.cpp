// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "camera_control.h"

#include "client/client.h"
#include "client/clientenvironment.h"
#include "client/content_cao.h"
#include "localplayer.h"

#include <cmath>

static constexpr u8 CAMFLAG_RESET = 1 << 0;
static constexpr u8 CAMFLAG_LOCK_PERSPECTIVE = 1 << 1;
static constexpr u8 CAMFLAG_LOCK_INPUT = 1 << 2;
static constexpr u8 CAMFLAG_DETACHED = 1 << 3;
static constexpr u8 CAMFLAG_ORBIT = 1 << 4;
static constexpr u8 CAMFLAG_SPECTATOR = 1 << 5;

static inline f32 clamp01(f32 x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }

f32 ClientCameraControl::wrapDegrees(f32 deg)
{
	deg = std::fmod(deg, 360.0f);
	if (deg < -180.0f)
		deg += 360.0f;
	if (deg > 180.0f)
		deg -= 360.0f;
	return deg;
}

f32 ClientCameraControl::shortestAngleDelta(f32 from, f32 to)
{
	from = wrapDegrees(from);
	to = wrapDegrees(to);
	f32 d = to - from;
	if (d > 180.0f)
		d -= 360.0f;
	if (d < -180.0f)
		d += 360.0f;
	return d;
}

f32 ClientCameraControl::lerpAngle(f32 a, f32 b, f32 t)
{
	return wrapDegrees(a + shortestAngleDelta(a, b) * t);
}

v3f ClientCameraControl::lerpAngles(const v3f &a, const v3f &b, f32 t)
{
	return v3f(
		lerpAngle(a.X, b.X, t),
		lerpAngle(a.Y, b.Y, t),
		lerpAngle(a.Z, b.Z, t));
}

f32 ClientCameraControl::ease01(f32 t, CameraEaseType type)
{
	t = clamp01(t);
	switch (type) {
	case CameraEaseType::Linear:
		return t;
	case CameraEaseType::InCubic:
		return t * t * t;
	case CameraEaseType::OutCubic: {
		f32 u = 1.0f - t;
		return 1.0f - u * u * u;
	}
	case CameraEaseType::InOutCubic:
		return t < 0.5f ? 4.0f * t * t * t : 1.0f - std::pow(-2.0f * t + 2.0f, 3.0f) / 2.0f;
	case CameraEaseType::OutBack: {
		const f32 c1 = 1.70158f;
		const f32 c3 = c1 + 1.0f;
		return 1.0f + c3 * std::pow(t - 1.0f, 3.0f) + c1 * std::pow(t - 1.0f, 2.0f);
	}
	case CameraEaseType::InBack: {
		const f32 c1 = 1.70158f;
		const f32 c3 = c1 + 1.0f;
		return c3 * t * t * t - c1 * t * t;
	}
	case CameraEaseType::OutElastic:
		if (t == 0.0f)
			return 0.0f;
		if (t == 1.0f)
			return 1.0f;
		return std::pow(2.0f, -10.0f * t) * std::sin((t * 10.0f - 0.75f) * (2.0f * float(M_PI) / 3.0f)) + 1.0f;
	case CameraEaseType::InOutBack: {
		const f32 c1 = 1.70158f;
		const f32 c2 = c1 * 1.525f;
		return t < 0.5f
			? (std::pow(2.0f * t, 2.0f) * ((c2 + 1.0f) * 2.0f * t - c2)) / 2.0f
			: (std::pow(2.0f * t - 2.0f, 2.0f) * ((c2 + 1.0f) * (t * 2.0f - 2.0f) + c2) + 2.0f) / 2.0f;
	}
	default:
		return t;
	}
}

void ClientCameraControl::rebuildPerspectiveLock()
{
	bool any_override = m_detached || m_orbit || m_spectator ||
		m_state.has_pos || m_state.has_rot || m_state.has_fov || m_state.has_tilt ||
		m_state.has_offset || m_state.has_third_person ||
		m_state.orbit_params.active || m_state.spectator_params.active ||
		m_state.shake.active || m_state.fade.active;
	m_perspective_locked = m_lock_perspective || any_override;
}

void ClientCameraControl::beginTrack(TrackF32 &tr, f32 current, bool has_target, f32 target,
		const CameraEaseSpec &ease, bool to_base)
{
	tr.start = current;
	tr.target = target;
	tr.elapsed = 0.0f;
	tr.ease = ease;
	tr.active = ease.time > 0.0f;
	tr.to_base = to_base;
	if (!tr.active && has_target)
		tr.cur = target;
}

void ClientCameraControl::beginTrack(TrackV3F &tr, const v3f &current, bool has_target, const v3f &target,
		const CameraEaseSpec &ease, bool to_base)
{
	tr.start = current;
	tr.target = target;
	tr.elapsed = 0.0f;
	tr.ease = ease;
	tr.active = ease.time > 0.0f;
	tr.to_base = to_base;
	if (!tr.active && has_target)
		tr.cur = target;
}

void ClientCameraControl::stepTrack(TrackF32 &tr, f32 dtime, f32 base_value)
{
	if (!tr.active) {
		if (tr.to_base)
			tr.cur = base_value;
		return;
	}
	tr.elapsed += dtime;
	f32 t = tr.ease.time > 0.0f ? clamp01(tr.elapsed / tr.ease.time) : 1.0f;
	f32 k = ease01(t, tr.ease.type);
	f32 target = tr.to_base ? base_value : tr.target;
	tr.cur = tr.start + (target - tr.start) * k;
	if (t >= 1.0f) {
		tr.active = false;
		tr.to_base = false;
		tr.cur = target;
	}
}

void ClientCameraControl::stepTrack(TrackV3F &tr, f32 dtime, const v3f &base_value)
{
	if (!tr.active) {
		if (tr.to_base)
			tr.cur = base_value;
		return;
	}
	tr.elapsed += dtime;
	f32 t = tr.ease.time > 0.0f ? clamp01(tr.elapsed / tr.ease.time) : 1.0f;
	f32 k = ease01(t, tr.ease.type);
	v3f target = tr.to_base ? base_value : tr.target;
	tr.cur = tr.start + (target - tr.start) * k;
	if (t >= 1.0f) {
		tr.active = false;
		tr.to_base = false;
		tr.cur = target;
	}
}

void ClientCameraControl::stepTrackAngles(TrackV3F &tr, f32 dtime, const v3f &base_angles)
{
	if (!tr.active) {
		if (tr.to_base)
			tr.cur = base_angles;
		return;
	}
	tr.elapsed += dtime;
	f32 t = tr.ease.time > 0.0f ? clamp01(tr.elapsed / tr.ease.time) : 1.0f;
	f32 k = ease01(t, tr.ease.type);
	v3f target = tr.to_base ? base_angles : tr.target;
	tr.cur = lerpAngles(tr.start, target, k);
	if (t >= 1.0f) {
		tr.active = false;
		tr.to_base = false;
		tr.cur = target;
	}
}

bool ClientCameraControl::consumeLookInput() const
{
	if (m_spectator && m_state.spectator_params.active)
		return true;
	return m_orbit && m_state.orbit_params.active && m_state.orbit_params.independent_look;
}

void ClientCameraControl::applyServerUpdate(const CameraControlState &st, u8 flags, u16 field_mask)
{
	const bool reset = (flags & CAMFLAG_RESET) != 0;

	if (reset) {
		m_state = CameraControlState();
		m_orbit_yaw_add = 0.0f;
		m_orbit_pitch_add = 0.0f;
		m_spectator_pos_nodes = v3f();
		m_spectator_rot_deg = v3f();
		m_spectator_yaw_add = 0.0f;
		m_spectator_pitch_add = 0.0f;
		m_move_input = v2f();
		m_move_up = m_move_down = m_move_sprint = false;
		m_shake_t = 0.0f;
		m_fade_t = 0.0f;
	}

	m_lock_perspective = (flags & CAMFLAG_LOCK_PERSPECTIVE) != 0;
	m_lock_input = (flags & CAMFLAG_LOCK_INPUT) != 0;
	m_detached = (flags & CAMFLAG_DETACHED) != 0;
	m_orbit = (flags & CAMFLAG_ORBIT) != 0;
	m_spectator = (flags & CAMFLAG_SPECTATOR) != 0;

	if (field_mask & CAMCTRL_POS) {
		m_state.has_pos = st.has_pos;
		m_state.pos = st.pos;
		m_state.pos_ease = st.pos_ease;
		beginTrack(m_pos, m_pos.cur, st.has_pos, st.pos, st.pos_ease, !st.has_pos);
	}

	if (field_mask & CAMCTRL_ROT) {
		m_state.has_rot = st.has_rot;
		m_state.rot_deg = st.rot_deg;
		m_state.rot_ease = st.rot_ease;
		beginTrack(m_rot, m_rot.cur, st.has_rot, st.rot_deg, st.rot_ease, !st.has_rot);
	}

	if (field_mask & CAMCTRL_FOV) {
		m_state.has_fov = st.has_fov;
		m_state.fov_deg = st.fov_deg;
		m_state.fov_ease = st.fov_ease;
		beginTrack(m_fov, m_fov.cur, st.has_fov, st.fov_deg, st.fov_ease, !st.has_fov);
	}

	if (field_mask & CAMCTRL_TILT) {
		m_state.has_tilt = st.has_tilt;
		m_state.tilt_deg = st.tilt_deg;
		m_state.tilt_ease = st.tilt_ease;
		m_state.tilt_auto_return = st.tilt_auto_return;
		beginTrack(m_tilt, m_tilt.cur, st.has_tilt, st.tilt_deg, st.tilt_ease, !st.has_tilt);
	}

	if (field_mask & CAMCTRL_OFFSET) {
		m_state.has_offset = st.has_offset;
		m_state.pos_offset = st.pos_offset;
		m_state.rot_offset_deg = st.rot_offset_deg;
		m_state.offset_ease = st.offset_ease;
		beginTrack(m_pos_offset, m_pos_offset.cur, st.has_offset, st.pos_offset, st.offset_ease, !st.has_offset);
		beginTrack(m_rot_offset, m_rot_offset.cur, st.has_offset, st.rot_offset_deg, st.offset_ease, !st.has_offset);
	}

	if (field_mask & CAMCTRL_THIRD_PERSON) {
		m_state.has_third_person = st.has_third_person;
		m_state.third_person_distance = st.third_person_distance;
		m_state.third_person_ease = st.third_person_ease;
		beginTrack(m_third_person, m_third_person.cur, st.has_third_person, st.third_person_distance,
			st.third_person_ease, !st.has_third_person);
	}

	if (field_mask & CAMCTRL_ORBIT)
		m_state.orbit_params = st.orbit_params;
	if (field_mask & CAMCTRL_SPECTATOR)
		m_state.spectator_params = st.spectator_params;
	if (field_mask & CAMCTRL_SHAKE) {
		m_state.shake = st.shake;
		m_shake_t = 0.0f;
	}
	if (field_mask & CAMCTRL_FADE) {
		m_state.fade = st.fade;
		m_fade = st.fade;
		m_fade_t = 0.0f;
	}

	rebuildPerspectiveLock();
}

void ClientCameraControl::onLookInput(f32 dyaw_deg, f32 dpitch_deg)
{
	if (m_spectator && m_state.spectator_params.active) {
		m_spectator_yaw_add += dyaw_deg;
		m_spectator_pitch_add = rangelim(m_spectator_pitch_add + dpitch_deg, -89.0f, 89.0f);
		return;
	}
	m_orbit_yaw_add += dyaw_deg;
	m_orbit_pitch_add = rangelim(m_orbit_pitch_add + dpitch_deg, -89.0f, 89.0f);
}

void ClientCameraControl::onMoveInput(v2f move, bool up, bool down, bool sprint)
{
	m_move_input = move;
	m_move_up = up;
	m_move_down = down;
	m_move_sprint = sprint;
}

static inline v3f rotateLocalOffsetYawOnly(const v3f &off, f32 yaw_deg)
{
	v3f v = off;
	v.rotateXZBy(yaw_deg);
	return v;
}

std::optional<video::SColor> ClientCameraControl::getFadeOverlayColor() const
{
	if (!m_fade.active)
		return std::nullopt;

	f32 t = m_fade_t;
	f32 in = std::max(0.0f, m_fade.fade_in);
	f32 hold = std::max(0.0f, m_fade.hold);
	f32 out = std::max(0.0f, m_fade.fade_out);
	f32 total = in + hold + out;
	if (total <= 0.0f)
		total = 0.0f;

	f32 alpha01 = 0.0f;
	if (in > 0.0f && t < in) {
		alpha01 = t / in;
	} else if (t < in + hold) {
		alpha01 = 1.0f;
	} else if (out > 0.0f && t < in + hold + out) {
		alpha01 = 1.0f - (t - (in + hold)) / out;
	} else if (out <= 0.0f && t >= in + hold) {
		alpha01 = 0.0f;
	}
	alpha01 = clamp01(alpha01);

	u8 a = (m_fade.color_argb >> 24) & 0xFF;
	u8 r = (m_fade.color_argb >> 16) & 0xFF;
	u8 g = (m_fade.color_argb >> 8) & 0xFF;
	u8 b = (m_fade.color_argb) & 0xFF;

	u8 alpha = (u8)std::round(alpha01 * a);
	if (alpha == 0)
		return std::nullopt;
	return video::SColor(alpha, r, g, b);
}

void ClientCameraControl::step(f32 dtime, Client *client, LocalPlayer *player,
		const v3f &base_pos_bs, const v3f &base_rot_deg)
{
	if (!player)
		return;

	// Ease tracks towards either their target or the base value.
	stepTrack(m_pos, dtime, base_pos_bs / BS);
	stepTrackAngles(m_rot, dtime, base_rot_deg);
	stepTrack(m_fov, dtime, 0.0f);
	stepTrack(m_tilt, dtime, 0.0f);
	stepTrack(m_pos_offset, dtime, v3f());
	stepTrack(m_rot_offset, dtime, v3f());
	stepTrack(m_third_person, dtime, 0.0f);

	// tilt auto-return: when transition completes and auto-return is set, go back to 0
	if (m_state.has_tilt && m_state.tilt_auto_return && !m_tilt.active && std::fabs(m_tilt.cur) > 1e-3f) {
		CameraEaseSpec e = m_state.tilt_ease;
		beginTrack(m_tilt, m_tilt.cur, true, 0.0f, e, false);
		m_state.has_tilt = true;
		m_state.tilt_deg = 0.0f;
	}

	m_fade = m_state.fade;
	if (m_fade.active)
		m_fade_t += dtime;

	m_has_fov = false;
	if (m_state.has_fov) {
		m_has_fov = true;
		m_fov_deg = m_fov.cur;
	}

	m_force_third_person = false;
	m_third_person_distance_bs = 0.0f;
	if (m_state.has_third_person) {
		m_force_third_person = m_third_person.cur > 0.001f;
		m_third_person_distance_bs = m_third_person.cur * BS;
	}

	v3f pos_nodes = base_pos_bs / BS;
	v3f rot = base_rot_deg;

	// Attached offset in local body space (yaw only)
	if (m_state.has_offset || m_pos_offset.active || m_rot_offset.active) {
		pos_nodes += rotateLocalOffsetYawOnly(m_pos_offset.cur, rot.Y);
		rot += m_rot_offset.cur;
	}

	if (detached()) {
		if (m_state.has_pos || m_pos.active)
			pos_nodes = m_pos.cur;
		if (m_state.has_rot || m_rot.active)
			rot = m_rot.cur;
	}

	// Orbit mode overrides
	if (m_orbit && m_state.orbit_params.active) {
		v3f target_nodes = pos_nodes;
		switch (m_state.orbit_params.target_type) {
		case 0: // player
			target_nodes = base_pos_bs / BS;
			break;
		case 1: { // entity
			ClientActiveObject *cao = client ? client->getEnv().getActiveObject(m_state.orbit_params.target_object_id) : nullptr;
			if (cao)
				target_nodes = cao->getPosition() / BS;
			break;
		}
		case 2: // pos
			target_nodes = m_state.orbit_params.target_pos;
			break;
		default:
			break;
		}

		f32 oyaw = base_rot_deg.Y + m_state.orbit_params.yaw_offset + m_orbit_yaw_add;
		f32 opitch = base_rot_deg.X + m_state.orbit_params.pitch_offset + m_orbit_pitch_add;

		v3f dir(0, 0, 1);
		dir.rotateYZBy(opitch);
		dir.rotateXZBy(oyaw);
		pos_nodes = target_nodes + m_state.orbit_params.view_offset - dir * m_state.orbit_params.radius;
		rot = v3f(opitch, oyaw, 0.0f);
	}

	// Spectator mode overrides
	if (m_spectator && m_state.spectator_params.active) {
		if (m_spectator_pos_nodes == v3f()) {
			m_spectator_pos_nodes = pos_nodes;
			m_spectator_rot_deg = rot;
		}

		m_spectator_rot_deg.X = rangelim(m_spectator_rot_deg.X + m_spectator_pitch_add, -89.0f, 89.0f);
		m_spectator_rot_deg.Y = wrapDegrees(m_spectator_rot_deg.Y + m_spectator_yaw_add);
		m_spectator_pitch_add = 0.0f;
		m_spectator_yaw_add = 0.0f;

		f32 spd = m_state.spectator_params.speed;
		if (m_move_sprint)
			spd *= m_state.spectator_params.sprint_multiplier;

		v3f forward(0, 0, 1);
		forward.rotateYZBy(m_spectator_rot_deg.X);
		forward.rotateXZBy(m_spectator_rot_deg.Y);
		v3f right(1, 0, 0);
		right.rotateXZBy(m_spectator_rot_deg.Y);

		v3f delta = (forward * m_move_input.Y + right * m_move_input.X) * (spd * dtime);
		if (m_state.spectator_params.vertical) {
			if (m_move_up)
				delta.Y += spd * dtime;
			if (m_move_down)
				delta.Y -= spd * dtime;
		}
		m_spectator_pos_nodes += delta;

		pos_nodes = m_spectator_pos_nodes;
		rot = m_spectator_rot_deg;
	}

	// Apply tilt as roll
	rot.Z += m_tilt.cur;

	// Apply shake as additional small rotations
	if (m_state.shake.active && m_state.shake.duration > 0.0f && m_state.shake.intensity > 0.0f) {
		m_shake_t += dtime;
		f32 t = clamp01(m_shake_t / m_state.shake.duration);
		f32 k = m_state.shake.intensity;
		if (m_state.shake.decay)
			k *= (1.0f - t);
		f32 s1 = std::sin(m_shake_t * 19.17f);
		f32 s2 = std::sin(m_shake_t * 27.43f);
		f32 s3 = std::sin(m_shake_t * 13.11f);
		if (m_state.shake.axes_mask & 0x01) rot.X += s1 * k;
		if (m_state.shake.axes_mask & 0x02) rot.Y += s2 * k;
		if (m_state.shake.axes_mask & 0x04) rot.Z += s3 * k;
		if (m_shake_t >= m_state.shake.duration)
			m_state.shake.active = false;
	}

	// Build direction + up from rotation
	core::matrix4 mat;
	mat.setRotationDegrees(rot);
	v3f dir(0, 0, 1);
	v3f up(0, 1, 0);
	mat.rotateVect(dir);
	mat.rotateVect(up);

	m_cam_pos_bs = pos_nodes * BS;
	m_cam_dir = dir.normalize();
	m_cam_up = up.normalize();
}
