import org.json.JSONObject;

public class CameraMod implements LuantiMod {

    private float angle  = 0f;
    private float radius = 4.0f;
    private float height = 2.0f;
    private float speed  = 45.0f;
    private boolean active = false;

    private float playerX = 0f;
    private float playerY = 0f;
    private float playerZ = 0f;

    @Override
    public void change(String target, String propsJson) {
        try {
            JSONObject p = new JSONObject(propsJson);
            if (p.has("active"))  active = p.getBoolean("active");
            if (p.has("radius"))  radius = (float) p.getDouble("radius");
            if (p.has("height"))  height = (float) p.getDouble("height");
            if (p.has("speed"))   speed  = (float) p.getDouble("speed");
        } catch (Exception e) { e.printStackTrace(); }
    }

    @Override
    public void update(String target, String propsJson) {
        if (!active) return;
        try {
            JSONObject p = new JSONObject(propsJson);
            float dtime = (float) p.optDouble("dtime", 0.033);
            if (p.has("player_x")) {
                playerX = (float) p.getDouble("player_x");
                playerY = (float) p.getDouble("player_y");
                playerZ = (float) p.getDouble("player_z");
            }
            angle += speed * dtime;
            if (angle >= 360f) angle -= 360f;

            double rad = Math.toRadians(angle);
            float camX = playerX + (float)(Math.cos(rad) * radius);
            float camY = playerY + height;
            float camZ = playerZ + (float)(Math.sin(rad) * radius);

            // Apply camera position to engine
            nativeSetCamera(camX, camY, camZ, playerX, playerY, playerZ);
        } catch (Exception e) { e.printStackTrace(); }
    }

    @Override
    public void add(String type, String propsJson) {
        // not used
    }

    @Override
    public void remove(String target) {
        active = false;
        nativeResetCamera();
    }

    // These native methods are provided by the fork's JNI bridge
    private native void nativeSetCamera(float x, float y, float z,
                                         float lookX, float lookY, float lookZ);
    private native void nativeResetCamera();
}
