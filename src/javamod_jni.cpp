// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef __ANDROID__

#include "javamod_jni.h"
#include "log.h"
#include <jni.h>
#define SDL_MAIN_HANDLED 1
#include <SDL.h>

static bool getActivityEnv(JNIEnv **out_env, jobject *out_activity, jclass *out_activity_class)
{
	JNIEnv *env = (JNIEnv *)SDL_AndroidGetJNIEnv();
	if (!env)
		return false;
	jobject activity = (jobject)SDL_AndroidGetActivity();
	if (!activity)
		return false;
	jclass activityClass = env->GetObjectClass(activity);
	if (!activityClass)
		return false;
	*out_env = env;
	*out_activity = activity;
	*out_activity_class = activityClass;
	return true;
}

static void callVoidMethod2Str(const char *method_name, const std::string &a, const std::string &b)
{
	JNIEnv *env;
	jobject activity;
	jclass activityClass;
	if (!getActivityEnv(&env, &activity, &activityClass))
		return;

	jmethodID mid = env->GetMethodID(activityClass, method_name,
		"(Ljava/lang/String;Ljava/lang/String;)V");
	if (!mid) {
		errorstream << "javamod_jni: missing method " << method_name << std::endl;
		env->DeleteLocalRef(activityClass);
		return;
	}

	jstring ja = env->NewStringUTF(a.c_str());
	jstring jb = env->NewStringUTF(b.c_str());
	env->CallVoidMethod(activity, mid, ja, jb);
	if (ja) env->DeleteLocalRef(ja);
	if (jb) env->DeleteLocalRef(jb);
	env->DeleteLocalRef(activityClass);
}

static void callVoidMethod3Str(const char *method_name, const std::string &a,
		const std::string &b, const std::string &c)
{
	JNIEnv *env;
	jobject activity;
	jclass activityClass;
	if (!getActivityEnv(&env, &activity, &activityClass))
		return;

	jmethodID mid = env->GetMethodID(activityClass, method_name,
		"(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
	if (!mid) {
		errorstream << "javamod_jni: missing method " << method_name << std::endl;
		env->DeleteLocalRef(activityClass);
		return;
	}

	jstring ja = env->NewStringUTF(a.c_str());
	jstring jb = env->NewStringUTF(b.c_str());
	jstring jc = env->NewStringUTF(c.c_str());
	env->CallVoidMethod(activity, mid, ja, jb, jc);
	if (ja) env->DeleteLocalRef(ja);
	if (jb) env->DeleteLocalRef(jb);
	if (jc) env->DeleteLocalRef(jc);
	env->DeleteLocalRef(activityClass);
}

void javamod_jni_load(const std::string &id, const std::string &dex_path)
{
	callVoidMethod2Str("javamod_load", id, dex_path);
}

void javamod_jni_change(const std::string &id, const std::string &target, const std::string &properties_json)
{
	callVoidMethod3Str("javamod_change", id, target, properties_json);
}

void javamod_jni_add(const std::string &id, const std::string &type, const std::string &properties_json)
{
	callVoidMethod3Str("javamod_add", id, type, properties_json);
}

void javamod_jni_remove(const std::string &id, const std::string &target)
{
	callVoidMethod2Str("javamod_remove", id, target);
}

void javamod_jni_update_all(const std::string &target, const std::string &properties_json)
{
	callVoidMethod2Str("javamod_update_all", target, properties_json);
}

#endif // __ANDROID__
