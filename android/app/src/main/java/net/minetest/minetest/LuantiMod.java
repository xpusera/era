package net.minetest.minetest;

import android.app.Activity;
import android.content.Context;

public interface LuantiMod {
    void init(Activity activity, Context context);
    void change(String target, String propertiesJson);
    void update(String target, String propertiesJson);
    void add(String type, String propertiesJson);
    void remove(String target);
}
