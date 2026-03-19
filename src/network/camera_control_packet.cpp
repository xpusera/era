// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "camera_control_packet.h"

#include "networkpacket.h"

static inline void writeEase(NetworkPacket &pkt, const CameraEaseSpec &e)
{
	pkt << e.time << static_cast<u8>(e.type);
}

static inline void readEase(NetworkPacket &pkt, CameraEaseSpec &e)
{
	u8 t;
	pkt >> e.time >> t;
	e.type = static_cast<CameraEaseType>(t);
}

void camera_control_serialize(NetworkPacket &pkt, const CameraControlState &st,
	u8 flags, u16 field_mask)
{
	pkt << flags;
	pkt << field_mask;

	if (field_mask & CAMCTRL_POS) {
		pkt << st.has_pos;
		if (st.has_pos)
			pkt << st.pos;
		writeEase(pkt, st.pos_ease);
	}

	if (field_mask & CAMCTRL_ROT) {
		pkt << st.has_rot;
		if (st.has_rot)
			pkt << st.rot_deg;
		writeEase(pkt, st.rot_ease);
	}

	if (field_mask & CAMCTRL_FOV) {
		pkt << st.has_fov;
		if (st.has_fov)
			pkt << st.fov_deg;
		writeEase(pkt, st.fov_ease);
	}

	if (field_mask & CAMCTRL_TILT) {
		pkt << st.has_tilt;
		if (st.has_tilt)
			pkt << st.tilt_deg;
		writeEase(pkt, st.tilt_ease);
		pkt << st.tilt_auto_return;
	}

	if (field_mask & CAMCTRL_OFFSET) {
		pkt << st.has_offset;
		if (st.has_offset)
			pkt << st.pos_offset << st.rot_offset_deg;
		writeEase(pkt, st.offset_ease);
	}

	if (field_mask & CAMCTRL_THIRD_PERSON) {
		pkt << st.has_third_person;
		if (st.has_third_person)
			pkt << st.third_person_distance;
		writeEase(pkt, st.third_person_ease);
	}

	if (field_mask & CAMCTRL_ORBIT) {
		pkt << st.orbit_params.active;
		if (st.orbit_params.active) {
			pkt << st.orbit_params.target_type;
			pkt << st.orbit_params.target_object_id;
			pkt << st.orbit_params.target_pos;
			pkt << st.orbit_params.radius;
			pkt << st.orbit_params.yaw_offset;
			pkt << st.orbit_params.pitch_offset;
			pkt << st.orbit_params.view_offset;
			pkt << st.orbit_params.independent_look;
		}
	}

	if (field_mask & CAMCTRL_SPECTATOR) {
		pkt << st.spectator_params.active;
		if (st.spectator_params.active) {
			pkt << st.spectator_params.speed;
			pkt << st.spectator_params.sprint_multiplier;
			pkt << st.spectator_params.vertical;
		}
	}

	if (field_mask & CAMCTRL_SHAKE) {
		pkt << st.shake.active;
		if (st.shake.active) {
			pkt << st.shake.intensity << st.shake.duration;
			pkt << st.shake.decay;
			pkt << st.shake.axes_mask;
		}
	}

	if (field_mask & CAMCTRL_FADE) {
		pkt << st.fade.active;
		if (st.fade.active) {
			pkt << st.fade.color_argb;
			pkt << st.fade.fade_in << st.fade.hold << st.fade.fade_out;
		}
	}
}

bool camera_control_deserialize(NetworkPacket &pkt, CameraControlState &st,
	u8 *flags_out, u16 *field_mask_out)
{
	u8 flags;
	u16 field_mask;
	pkt >> flags >> field_mask;

	if (flags_out)
		*flags_out = flags;
	if (field_mask_out)
		*field_mask_out = field_mask;

	if (field_mask & CAMCTRL_POS) {
		pkt >> st.has_pos;
		if (st.has_pos)
			pkt >> st.pos;
		readEase(pkt, st.pos_ease);
	}

	if (field_mask & CAMCTRL_ROT) {
		pkt >> st.has_rot;
		if (st.has_rot)
			pkt >> st.rot_deg;
		readEase(pkt, st.rot_ease);
	}

	if (field_mask & CAMCTRL_FOV) {
		pkt >> st.has_fov;
		if (st.has_fov)
			pkt >> st.fov_deg;
		readEase(pkt, st.fov_ease);
	}

	if (field_mask & CAMCTRL_TILT) {
		pkt >> st.has_tilt;
		if (st.has_tilt)
			pkt >> st.tilt_deg;
		readEase(pkt, st.tilt_ease);
		pkt >> st.tilt_auto_return;
	}

	if (field_mask & CAMCTRL_OFFSET) {
		pkt >> st.has_offset;
		if (st.has_offset)
			pkt >> st.pos_offset >> st.rot_offset_deg;
		readEase(pkt, st.offset_ease);
	}

	if (field_mask & CAMCTRL_THIRD_PERSON) {
		pkt >> st.has_third_person;
		if (st.has_third_person)
			pkt >> st.third_person_distance;
		readEase(pkt, st.third_person_ease);
	}

	if (field_mask & CAMCTRL_ORBIT) {
		pkt >> st.orbit_params.active;
		if (st.orbit_params.active) {
			pkt >> st.orbit_params.target_type;
			pkt >> st.orbit_params.target_object_id;
			pkt >> st.orbit_params.target_pos;
			pkt >> st.orbit_params.radius;
			pkt >> st.orbit_params.yaw_offset;
			pkt >> st.orbit_params.pitch_offset;
			pkt >> st.orbit_params.view_offset;
			pkt >> st.orbit_params.independent_look;
		}
	}

	if (field_mask & CAMCTRL_SPECTATOR) {
		pkt >> st.spectator_params.active;
		if (st.spectator_params.active) {
			pkt >> st.spectator_params.speed;
			pkt >> st.spectator_params.sprint_multiplier;
			pkt >> st.spectator_params.vertical;
		}
	}

	if (field_mask & CAMCTRL_SHAKE) {
		pkt >> st.shake.active;
		if (st.shake.active) {
			pkt >> st.shake.intensity >> st.shake.duration;
			pkt >> st.shake.decay;
			pkt >> st.shake.axes_mask;
		}
	}

	if (field_mask & CAMCTRL_FADE) {
		pkt >> st.fade.active;
		if (st.fade.active) {
			pkt >> st.fade.color_argb;
			pkt >> st.fade.fade_in >> st.fade.hold >> st.fade.fade_out;
		}
	}

	return true;
}
