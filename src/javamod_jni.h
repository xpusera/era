// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#ifdef __ANDROID__
#include <string>

void javamod_jni_load(const std::string &id, const std::string &dex_path);
void javamod_jni_change(const std::string &id, const std::string &target, const std::string &properties_json);
void javamod_jni_add(const std::string &id, const std::string &type, const std::string &properties_json);
void javamod_jni_remove(const std::string &id, const std::string &target);
void javamod_jni_update_all(const std::string &target, const std::string &properties_json);
#endif
