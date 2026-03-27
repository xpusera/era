package net.minetest.mods;

import net.minetest.minetest.LuantiMod;
import org.json.JSONObject;
import android.util.Log;

public class CameraMod implements LuantiMod {
    private static final String TAG = "CameraMod";
    private float orbitAngle = 0.0f;
    private float radius = 4.0f;
    private float height = 2.0f;
    private float speed = 45.0f; // degrees per second
    private boolean active = false;

    @Override
    public void change(String target, String propertiesJson) {
        try {
            JSONObject json = new JSONObject(propertiesJson);

            if ("update".equals(target)) {
                if (!active) return;

                float dtime = (float) json.getDouble("dtime");
                float px = (float) json.getDouble("player_x");
                float py = (float) json.getDouble("player_y");
                float pz = (float) json.getDouble("player_z");

                orbitAngle += speed * dtime;
                if (orbitAngle >= 360f) orbitAngle -= 360f;

                double rad = Math.toRadians(orbitAngle);
                float camX = px + radius * (float) Math.cos(rad);
                float camZ = pz + radius * (float) Math.sin(rad);
                float camY = py + height;

                // Point camera at player
                float dx = px - camX;
                float dy = py - camY;
                float dz = pz - camZ;

                float yaw = (float) Math.toDegrees(Math.atan2(dz, dx));
                float pitch = (float) Math.toDegrees(Math.atan2(-dy, Math.sqrt(dx*dx + dz*dz)));

                // Example native call:
                // GameActivity.nativeSetCameraPosition(camX, camY, camZ, yaw, pitch);
                return;
            }

            if (json.has("active")) this.active = json.getBoolean("active");
            if (json.has("radius")) this.radius = (float) json.getDouble("radius");
            if (json.has("height")) this.height = (float) json.getDouble("height");
            if (json.has("speed")) this.speed = (float) json.getDouble("speed");
            Log.i(TAG, "Configured orbit: active=" + active + ", radius=" + radius + ", speed=" + speed);
        } catch (Exception e) {
            Log.e(TAG, "Failed to handle change", e);
        }
    }

    @Override
    public void update(String target, String propertiesJson) {
        // Engine-called update (globalstep)
    }

    @Override
    public void add(String type, String propertiesJson) {}

    @Override
    public void remove(String target) {
        this.active = false;
    }
}
