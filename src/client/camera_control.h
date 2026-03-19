// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes.h"
#include "network/camera_control_packet.h"

#include <optional>

class Client;
class LocalPlayer;

class ClientCameraControl
{
public:
	void applyServerUpdate(const CameraControlState &st, u8 flags, u16 field_mask);

	void step(f32 dtime, Client *client, LocalPlayer *player,
			const v3f &base_pos_bs, const v3f &base_rot_deg);

	bool perspectiveLocked() const { return m_perspective_locked; }
	bool lockInput() const { return m_lock_input; }
	bool detached() const { return m_detached || m_orbit || m_spectator; }
	bool spectatorActive() const { return m_spectator && m_state.spectator_params.active; }
	bool consumeLookInput() const;

	void onLookInput(f32 dyaw_deg, f32 dpitch_deg);
	void onMoveInput(v2f move, bool up, bool down, bool sprint);

	v3f getCameraPosBS() const { return m_cam_pos_bs; }
	v3f getCameraDir() const { return m_cam_dir; }
	v3f getCameraUp() const { return m_cam_up; }

	bool hasFovOverride() const { return m_has_fov; }
	f32 getFovOverrideDeg() const { return m_fov_deg; }

	bool forceThirdPerson() const { return m_force_third_person; }
	f32 getThirdPersonDistanceBS() const { return m_third_person_distance_bs; }

	std::optional<video::SColor> getFadeOverlayColor() const;

private:
	struct TrackF32 {
		f32 cur = 0.0f;
		f32 start = 0.0f;
		f32 target = 0.0f;
		f32 elapsed = 0.0f;
		CameraEaseSpec ease;
		bool active = false;
		bool to_base = false;
	};

	struct TrackV3F {
		v3f cur = v3f();
		v3f start = v3f();
		v3f target = v3f();
		f32 elapsed = 0.0f;
		CameraEaseSpec ease;
		bool active = false;
		bool to_base = false;
	};

	static f32 ease01(f32 t, CameraEaseType type);
	static f32 wrapDegrees(f32 deg);
	static f32 shortestAngleDelta(f32 from, f32 to);
	static f32 lerpAngle(f32 a, f32 b, f32 t);
	static v3f lerpAngles(const v3f &a, const v3f &b, f32 t);

	void rebuildPerspectiveLock();
	void beginTrack(TrackF32 &tr, f32 current, bool has_target, f32 target,
			const CameraEaseSpec &ease, bool to_base);
	void beginTrack(TrackV3F &tr, const v3f &current, bool has_target, const v3f &target,
			const CameraEaseSpec &ease, bool to_base);
	void stepTrack(TrackF32 &tr, f32 dtime, f32 base_value);
	void stepTrackAngles(TrackV3F &tr, f32 dtime, const v3f &base_angles);
	void stepTrack(TrackV3F &tr, f32 dtime, const v3f &base_value);

	CameraControlState m_state;

	bool m_lock_perspective = false;
	bool m_lock_input = false;
	bool m_detached = false;
	bool m_orbit = false;
	bool m_spectator = false;

	bool m_perspective_locked = false;

	TrackV3F m_pos;
	TrackV3F m_rot;
	TrackF32 m_fov;
	TrackF32 m_tilt;
	TrackV3F m_pos_offset;
	TrackV3F m_rot_offset;
	TrackF32 m_third_person;

	// orbit state
	f32 m_orbit_yaw_add = 0.0f;
	f32 m_orbit_pitch_add = 0.0f;

	// spectator state
	v3f m_spectator_pos_nodes = v3f();
	v3f m_spectator_rot_deg = v3f();
	f32 m_spectator_yaw_add = 0.0f;
	f32 m_spectator_pitch_add = 0.0f;

	v2f m_move_input = v2f();
	bool m_move_up = false;
	bool m_move_down = false;
	bool m_move_sprint = false;

	// shake
	f32 m_shake_t = 0.0f;

	// fade
	CameraFadeParams m_fade;
	f32 m_fade_t = 0.0f;

	// computed
	v3f m_cam_pos_bs = v3f();
	v3f m_cam_dir = v3f(0, 0, 1);
	v3f m_cam_up = v3f(0, 1, 0);
	bool m_has_fov = false;
	f32 m_fov_deg = 0.0f;
	bool m_force_third_person = false;
	f32 m_third_person_distance_bs = 0.0f;
};
