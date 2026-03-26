package net.minetest.minetest;

public interface LuantiMod {
    void change(String target, String propertiesJson);
    void update(String target, String propertiesJson);
    void add(String type, String propertiesJson);
    void remove(String target);
}
