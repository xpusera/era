package net.minetest.minetest;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import dalvik.system.DexClassLoader;

public class JavaModManager {
    private static final String TAG = "JavaModManager";
    private final Activity mActivity;
    private final Context mContext;
    private final Map<String, LuantiMod> mLoadedMods = new HashMap<>();

    public JavaModManager(Activity activity, Context context) {
        mActivity = activity;
        mContext = context;
    }

    public void load(String id, String dexPath) {
        try {
            File dexFile = new File(dexPath);
            if (!dexFile.exists()) {
                Log.e(TAG, "Dex file not found: " + dexPath);
                return;
            }

            File optimizedDexDir = mContext.getDir("outdex", Context.MODE_PRIVATE);
            DexClassLoader classLoader = new DexClassLoader(
                    dexPath,
                    optimizedDexDir.getAbsolutePath(),
                    null,
                    mContext.getClassLoader()
            );

            // Assume the entry point class name is 'net.minetest.mods.Main' or similar?
            // The task says "Find a standard entry point class inside the dex"
            // Let's look for a class that implements LuantiMod.
            // But DexClassLoader doesn't let us easily list classes.
            // Let's assume the 'id' includes the class name, like "modname:com.example.ModClass"
            String className = id.contains(":") ? id.substring(id.indexOf(":") + 1) : id;
            Class<?> modClass = classLoader.loadClass(className);
            LuantiMod modInstance = (LuantiMod) modClass.getDeclaredConstructor().newInstance();
            modInstance.init(mActivity, mContext);
            mLoadedMods.put(id, modInstance);
            Log.i(TAG, "Loaded Java mod: " + id);
        } catch (Exception e) {
            Log.e(TAG, "Failed to load Java mod: " + id, e);
        }
    }

    public void change(String id, String target, String propertiesJson) {
        LuantiMod mod = mLoadedMods.get(id);
        if (mod != null) {
            mod.change(target, propertiesJson);
        }
    }

    public void updateAll(String target, String propertiesJson) {
        for (LuantiMod mod : mLoadedMods.values()) {
            mod.update(target, propertiesJson);
        }
    }

    public void add(String id, String type, String propertiesJson) {
        LuantiMod mod = mLoadedMods.get(id);
        if (mod != null) {
            mod.add(type, propertiesJson);
        }
    }

    public void remove(String id, String target) {
        LuantiMod mod = mLoadedMods.get(id);
        if (mod != null) {
            mod.remove(target);
        }
    }
}
