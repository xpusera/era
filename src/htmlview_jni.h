// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>

class ServerScripting;

#ifdef __ANDROID__

void htmlview_jni_run(const std::string &id, const std::string &html);
void htmlview_jni_run_external(const std::string &id, const std::string &root_dir,
		const std::string &entry);
void htmlview_jni_stop(const std::string &id);
void htmlview_jni_display(const std::string &id, int x, int y, int w, int h,
		bool visible, bool fullscreen, bool safe_area,
		bool drag_embed, float border_radius);
void htmlview_jni_send(const std::string &id, const std::string &message);
void htmlview_jni_navigate(const std::string &id, const std::string &url);
void htmlview_jni_inject(const std::string &id, const std::string &js);
void htmlview_jni_pipe(const std::string &fromId, const std::string &toId);

void htmlview_jni_poll(ServerScripting *script);

#endif
