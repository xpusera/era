// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes.h"
#include "irr_v3d.h"

class NetworkPacket;

enum class CameraEaseType : u8 {
	Linear = 0,
	InCubic,
	OutCubic,
	InOutCubic,
	OutBack,
	InBack,
	OutElastic,
	InOutBack,
};

struct CameraEaseSpec
{
	f32 time = 0.0f;
	CameraEaseType type = CameraEaseType::Linear;
};

struct CameraOrbitParams
{
	bool active = false;
	u8 target_type = 0; // 0=player, 1=entity, 2=pos
	u16 target_object_id = 0;
	v3f target_pos = v3f();
	f32 radius = 0.0f;
	f32 yaw_offset = 0.0f;
	f32 pitch_offset = 0.0f;
	v3f view_offset = v3f();
	bool independent_look = false;
};

struct CameraSpectatorParams
{
	bool active = false;
	f32 speed = 10.0f;
	f32 sprint_multiplier = 2.0f;
	bool vertical = true;
};

struct CameraShakeParams
{
	bool active = false;
	f32 intensity = 0.0f;
	f32 duration = 0.0f;
	bool decay = true;
	u8 axes_mask = 0x07; // bit0=pitch, bit1=yaw, bit2=roll
};

struct CameraFadeParams
{
	bool active = false;
	u32 color_argb = 0xFF000000;
	f32 fade_in = 0.0f;
	f32 hold = 0.0f;
	f32 fade_out = 0.0f;
};

struct CameraControlState
{
	bool lock_perspective = false;
	bool lock_input = false;
	bool detached = false;
	bool orbit = false;
	bool spectator = false;

	bool has_pos = false;
	v3f pos = v3f();
	CameraEaseSpec pos_ease;

	bool has_rot = false;
	v3f rot_deg = v3f(); // pitch,yaw,roll
	CameraEaseSpec rot_ease;

	bool has_fov = false;
	f32 fov_deg = 0.0f;
	CameraEaseSpec fov_ease;

	bool has_tilt = false;
	f32 tilt_deg = 0.0f;
	CameraEaseSpec tilt_ease;
	bool tilt_auto_return = false;

	bool has_offset = false;
	v3f pos_offset = v3f();
	v3f rot_offset_deg = v3f();
	CameraEaseSpec offset_ease;

	bool has_third_person = false;
	f32 third_person_distance = 0.0f;
	CameraEaseSpec third_person_ease;

	CameraOrbitParams orbit_params;
	CameraSpectatorParams spectator_params;
	CameraShakeParams shake;
	CameraFadeParams fade;
};

enum CameraControlFieldMask : u16 {
	CAMCTRL_POS = 1 << 0,
	CAMCTRL_ROT = 1 << 1,
	CAMCTRL_FOV = 1 << 2,
	CAMCTRL_TILT = 1 << 3,
	CAMCTRL_OFFSET = 1 << 4,
	CAMCTRL_THIRD_PERSON = 1 << 5,
	CAMCTRL_ORBIT = 1 << 6,
	CAMCTRL_SPECTATOR = 1 << 7,
	CAMCTRL_SHAKE = 1 << 8,
	CAMCTRL_FADE = 1 << 9,
	CAMCTRL_ALL = 0x03FF,
};

void camera_control_serialize(NetworkPacket &pkt, const CameraControlState &st,
	u8 flags, u16 field_mask);

bool camera_control_deserialize(NetworkPacket &pkt, CameraControlState &st,
	u8 *flags_out, u16 *field_mask_out);

