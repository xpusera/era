// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef __ANDROID__

#include "htmlview_jni.h"

#include "log.h"

#include <jni.h>
#define SDL_MAIN_HANDLED 1
#include <SDL.h>

#include <deque>
#include <mutex>

static std::string readJavaString(JNIEnv *env, jstring j_str)
{
	if (!j_str)
		return "";
	const char *c_str = env->GetStringUTFChars(j_str, nullptr);
	std::string str(c_str ? c_str : "");
	if (c_str)
		env->ReleaseStringUTFChars(j_str, c_str);
	return str;
}

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
		errorstream << "htmlview_jni: missing method " << method_name << std::endl;
		env->DeleteLocalRef(activityClass);
		return;
	}

	jstring ja = env->NewStringUTF(a.c_str());
	jstring jb = env->NewStringUTF(b.c_str());
	env->CallVoidMethod(activity, mid, ja, jb);
	if (ja)
		env->DeleteLocalRef(ja);
	if (jb)
		env->DeleteLocalRef(jb);
	env->DeleteLocalRef(activityClass);
}

static void callVoidMethod1Str(const char *method_name, const std::string &a)
{
	JNIEnv *env;
	jobject activity;
	jclass activityClass;
	if (!getActivityEnv(&env, &activity, &activityClass))
		return;

	jmethodID mid = env->GetMethodID(activityClass, method_name,
		"(Ljava/lang/String;)V");
	if (!mid) {
		errorstream << "htmlview_jni: missing method " << method_name << std::endl;
		env->DeleteLocalRef(activityClass);
		return;
	}

	jstring ja = env->NewStringUTF(a.c_str());
	env->CallVoidMethod(activity, mid, ja);
	if (ja)
		env->DeleteLocalRef(ja);
	env->DeleteLocalRef(activityClass);
}

void htmlview_jni_run(const std::string &id, const std::string &html)
{
	callVoidMethod2Str("htmlview_run", id, html);
}

void htmlview_jni_stop(const std::string &id)
{
	callVoidMethod1Str("htmlview_stop", id);
}

void htmlview_jni_display(const std::string &id, int x, int y, int w, int h,
		bool visible, bool fullscreen, bool safe_area)
{
	JNIEnv *env;
	jobject activity;
	jclass activityClass;
	if (!getActivityEnv(&env, &activity, &activityClass))
		return;

	jmethodID mid = env->GetMethodID(activityClass, "htmlview_display",
		"(Ljava/lang/String;IIIIZZZ)V");
	if (!mid) {
		errorstream << "htmlview_jni: missing method htmlview_display" << std::endl;
		env->DeleteLocalRef(activityClass);
		return;
	}

	jstring jid = env->NewStringUTF(id.c_str());
	jint jx = x;
	jint jy = y;
	jint jw = w;
	jint jh = h;
	jboolean jvis = visible;
	jboolean jfull = fullscreen;
	jboolean jsafe = safe_area;
	
	env->CallVoidMethod(activity, mid, jid, jx, jy, jw, jh, jvis, jfull, jsafe);
	if (jid)
		env->DeleteLocalRef(jid);
	env->DeleteLocalRef(activityClass);
}

void htmlview_jni_send(const std::string &id, const std::string &message)
{
	callVoidMethod2Str("htmlview_send", id, message);
}

struct HtmlViewMessage {
	std::string id;
	std::string message;
};

static std::mutex g_msg_mutex;
static std::deque<HtmlViewMessage> g_messages;

extern "C" JNIEXPORT void JNICALL
Java_net_minetest_minetest_HTMLViewManager_nativeOnHTMLMessage(
		JNIEnv *env, jclass, jstring id, jstring message)
{
	HtmlViewMessage m;
	m.id = readJavaString(env, id);
	m.message = readJavaString(env, message);
	{
		std::lock_guard<std::mutex> lock(g_msg_mutex);
		g_messages.push_back(std::move(m));
	}
}

#include "scripting_server.h"

void htmlview_jni_poll(ServerScripting *script)
{
	if (!script)
		return;
	std::deque<HtmlViewMessage> batch;
	{
		std::lock_guard<std::mutex> lock(g_msg_mutex);
		batch.swap(g_messages);
	}
	for (const auto &m : batch) {
		script->on_htmlview_message(m.id, m.message);
	}
}

#endif // __ANDROID__
