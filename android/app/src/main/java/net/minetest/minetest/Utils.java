package net.minetest.minetest;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.io.File;
import java.util.Locale;
import java.util.Objects;

public class Utils {
	private static boolean isXpName(@NonNull String name) {
		return name.toLowerCase(Locale.ROOT).endsWith(".xp");
	}

	@NonNull
	private static String sanitizeFilename(@NonNull String name) {
		String n = name.replace('\0', '_');
		n = n.replace('/', '_').replace('\\', '_');
		n = n.trim();
		if (n.isEmpty())
			n = "package";
		if (n.length() > 120)
			n = n.substring(0, 120);
		return n;
	}

	@NonNull
	private static String getDisplayName(@NonNull Context context, @NonNull Uri uri) {
		try {
			ContentResolver resolver = context.getContentResolver();
			try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
				if (cursor != null && cursor.moveToFirst()) {
					int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
					if (nameIndex >= 0) {
						String n = cursor.getString(nameIndex);
						if (n != null && !n.trim().isEmpty())
							return n;
					}
				}
			}
		} catch (Exception ignored) {
		}
		String seg = uri.getLastPathSegment();
		return seg != null ? seg : "package.xp";
	}

	@NonNull
	private static File uniqueFile(@NonNull File dir, @NonNull String name) {
		File f = new File(dir, name);
		if (!f.exists())
			return f;
		int dot = name.lastIndexOf('.');
		String base = (dot > 0) ? name.substring(0, dot) : name;
		String ext = (dot > 0) ? name.substring(dot) : "";
		for (int i = 2; i < 500; i++) {
			File c = new File(dir, base + "_" + i + ext);
			if (!c.exists())
				return c;
		}
		return new File(dir, base + "_" + System.currentTimeMillis() + ext);
	}

	private static void copyStream(@NonNull InputStream in, @NonNull OutputStream out) throws Exception {
		byte[] buf = new byte[8192];
		int n;
		while ((n = in.read(buf)) > 0) {
			out.write(buf, 0, n);
		}
	}

	private static int importXpFromUri(@NonNull Context context, @NonNull Uri uri) throws Exception {
		String rawName = getDisplayName(context, uri);
		String seg = uri.getLastPathSegment();
		boolean looksXp = isXpName(rawName) || (seg != null && isXpName(seg));
		if (!looksXp)
			return 0;

		String display = sanitizeFilename(rawName);
		if (!isXpName(display))
			display = display + ".xp";

		File userData = getUserDataDirectory(context);
		File importsDir = createDirs(userData, "imports");
		File dst = uniqueFile(importsDir, display);

		String scheme = uri.getScheme();
		try (InputStream in = ("file".equals(scheme) ? new FileInputStream(new File(uri.getPath()))
				: context.getContentResolver().openInputStream(uri))) {
			if (in == null)
				return 0;
			try (OutputStream out = new FileOutputStream(dst)) {
				copyStream(in, out);
			}
		}

		File pending = new File(importsDir, ".pending_xp_imports.txt");
		try (FileOutputStream fos = new FileOutputStream(pending, true)) {
			fos.write(dst.getAbsolutePath().getBytes(StandardCharsets.UTF_8));
			fos.write('\n');
		}

		return 1;
	}

	public static int importXpFromIntent(@NonNull Context context, @NonNull Intent intent) {
		try {
			String action = intent.getAction();
			if (Intent.ACTION_VIEW.equals(action)) {
				Uri uri = intent.getData();
				if (uri == null)
					return 0;
				return importXpFromUri(context, uri);
			}

			if (Intent.ACTION_SEND.equals(action)) {
				Uri uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
				if (uri == null)
					return 0;
				return importXpFromUri(context, uri);
			}

			if (Intent.ACTION_SEND_MULTIPLE.equals(action)) {
				int ok = 0;
				if (intent.getClipData() != null) {
					int n = intent.getClipData().getItemCount();
					for (int i = 0; i < n; i++) {
						Uri uri = intent.getClipData().getItemAt(i).getUri();
						if (uri != null)
							ok += importXpFromUri(context, uri);
					}
				} else if (intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM) != null) {
					for (Uri uri : Objects.requireNonNull(intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM))) {
						if (uri != null)
							ok += importXpFromUri(context, uri);
					}
				}
				return ok;
			}

			return 0;
		} catch (Exception e) {
			Log.w("Utils", "importXpFromIntent failed", e);
			return 0;
		}
	}

	@NonNull
	public static File createDirs(@NonNull File root, @NonNull String dir) {
		File f = new File(root, dir);
		if (!f.isDirectory())
			if (!f.mkdirs())
				Log.e("Utils", "Directory " + dir + " cannot be created");

		return f;
	}

	@NonNull
	public static File getUserDataDirectory(@NonNull Context context) {
		File extDir = Objects.requireNonNull(
			context.getExternalFilesDir(null),
			"Cannot get external file directory"
		);
		return createDirs(extDir, "Minetest");
	}

	@NonNull
	public static File getCacheDirectory(@NonNull Context context) {
		return Objects.requireNonNull(
			context.getCacheDir(),
			"Cannot get cache directory"
		);
	}

	public static boolean isInstallValid(@NonNull Context context) {
		File userDataDirectory = getUserDataDirectory(context);
		return userDataDirectory.isDirectory() &&
			new File(userDataDirectory, "builtin").isDirectory() &&
			new File(userDataDirectory, "client").isDirectory() &&
			new File(userDataDirectory, "textures").isDirectory();
	}
}
