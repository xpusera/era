package net.minetest.minetest;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

public class XpImportActivity extends Activity {
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		handleIntent(getIntent());
		launchMain();
		finish();
	}

	@Override
	protected void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		handleIntent(intent);
		launchMain();
		finish();
	}

	private void launchMain() {
		Intent i = new Intent(this, MainActivity.class);
		i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
		startActivity(i);
	}

	private void handleIntent(Intent intent) {
		try {
			int imported = Utils.importXpFromIntent(this, intent);
			if (imported > 0) {
				Toast.makeText(this, "Imported " + imported + " .xp package(s)", Toast.LENGTH_SHORT).show();
			}
		} catch (Exception ignored) {
		}
	}
}

