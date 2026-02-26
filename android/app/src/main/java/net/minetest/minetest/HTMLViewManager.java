package net.minetest.minetest;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Outline;
import android.graphics.PorterDuff;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.MimeTypeMap;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import androidx.annotation.Keep;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

@Keep
@SuppressWarnings({"unused", "WeakerAccess"})
public class HTMLViewManager {
	private static final int CENTER_SENTINEL = Integer.MIN_VALUE;

	private final GameActivity activity;
	private final ViewGroup root;
	private final HashMap<String, HtmlViewState> views = new HashMap<>();
	private final HashMap<String, String> pipes = new HashMap<>();
	private final Handler handler = new Handler(Looper.getMainLooper());
	private final HashMap<String, TextureLoop> textureLoops = new HashMap<>();

	public HTMLViewManager(GameActivity activity, ViewGroup root) {
		this.activity = activity;
		this.root = root;
	}

	public void shutdown() {
		activity.runOnUiThread(() -> {
			for (HtmlViewState st : views.values()) {
				try {
					root.removeView(st.container);
				} catch (Exception ignored) {
				}
				try {
					st.webView.destroy();
				} catch (Exception ignored) {
				}
			}
			for (TextureLoop loop : textureLoops.values()) {
				try {
					handler.removeCallbacks(loop.runnable);
				} catch (Exception ignored) {
				}
				try {
					if (loop.bmp != null) {
						loop.bmp.recycle();
						loop.bmp = null;
					}
				} catch (Exception ignored) {
				}
				loop.canvas = null;
				loop.pixels = null;
			}
			textureLoops.clear();
			views.clear();
			pipes.clear();
		});
	}

	public void htmlview_run(String id, String html) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = getOrCreate(id);
			st.externalRootDir = null;
			st.externalEntry = null;
			String injected = injectBridge(html);
			st.webView.loadDataWithBaseURL(st.baseUrl, injected, "text/html", "utf-8", null);
		});
	}

	public void htmlview_run_external(String id, String rootDir, String entry) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = getOrCreate(id);
			st.externalRootDir = rootDir;
			st.externalEntry = normalizeEntry(entry);
			st.webView.loadUrl(st.baseUrl + st.externalEntry);
		});
	}

	public void htmlview_stop(String id) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.remove(id);
			if (st == null)
				return;
			try {
				root.removeView(st.container);
			} catch (Exception ignored) {
			}
			try {
				st.webView.destroy();
			} catch (Exception ignored) {
			}
		});
	}

	public void htmlview_display(String id, int x, int y, int width, int height,
								boolean visible, boolean fullscreen, boolean safe_area,
								boolean drag_embed, float border_radius) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.get(id);
			if (st == null)
				return;

			st.container.setVisibility(visible ? View.VISIBLE : View.GONE);
			if (!visible)
				return;

			st.lastSafeArea = safe_area;
			st.lastFullscreen = fullscreen;

			int rootW = root.getWidth();
			int rootH = root.getHeight();
			if (rootW <= 0)
				rootW = activity.getResources().getDisplayMetrics().widthPixels;
			if (rootH <= 0)
				rootH = activity.getResources().getDisplayMetrics().heightPixels;

			Insets insets = Insets.NONE;
			if (safe_area) {
				WindowInsetsCompat wi = ViewCompat.getRootWindowInsets(root);
				if (wi != null) {
					insets = wi.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
				}
			}

			int safeL = insets.left;
			int safeT = insets.top;
			int safeR = rootW - insets.right;
			int safeB = rootH - insets.bottom;

			int availW = Math.max(0, safeR - safeL);
			int availH = Math.max(0, safeB - safeT);

			int finalW;
			int finalH;
			int finalX;
			int finalY;

			int marginR = safe_area ? insets.right : 0;
			int marginB = safe_area ? insets.bottom : 0;

			if (fullscreen) {
				finalW = ViewGroup.LayoutParams.MATCH_PARENT;
				finalH = ViewGroup.LayoutParams.MATCH_PARENT;
				finalX = safe_area ? safeL : 0;
				finalY = safe_area ? safeT : 0;
			} else {
				finalW = Math.max(1, width);
				finalH = Math.max(1, height);

				if (safe_area) {
					if (finalW > availW)
						finalW = availW;
					if (finalH > availH)
						finalH = availH;
				}
				finalW = Math.max(1, finalW);
				finalH = Math.max(1, finalH);

				finalX = x;
				finalY = y;

				if (finalX == CENTER_SENTINEL)
					finalX = safeL + Math.max(0, (availW - finalW) / 2);
				if (finalY == CENTER_SENTINEL)
					finalY = safeT + Math.max(0, (availH - finalH) / 2);

				if (safe_area) {
					finalX = clamp(finalX, safeL, safeR - finalW);
					finalY = clamp(finalY, safeT, safeB - finalH);
				}
			}

			FrameLayout.LayoutParams lp;
			if (st.container.getLayoutParams() instanceof FrameLayout.LayoutParams) {
				lp = (FrameLayout.LayoutParams) st.container.getLayoutParams();
			} else {
				lp = new FrameLayout.LayoutParams(1, 1);
			}
			lp.gravity = Gravity.TOP | Gravity.START;

			lp.width = (finalW == ViewGroup.LayoutParams.MATCH_PARENT) ? ViewGroup.LayoutParams.MATCH_PARENT : finalW;
			lp.height = (finalH == ViewGroup.LayoutParams.MATCH_PARENT) ? ViewGroup.LayoutParams.MATCH_PARENT : finalH;

			lp.leftMargin = Math.max(0, finalX);
			lp.topMargin = Math.max(0, finalY);
			lp.rightMargin = fullscreen ? marginR : 0;
			lp.bottomMargin = fullscreen ? marginB : 0;
			st.container.setLayoutParams(lp);

			setBorderRadiusPx(st, Math.max(0.0f, border_radius));
			setDragEnabled(st, drag_embed && !fullscreen);
		});
	}

	public void htmlview_send(String id, String message) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.get(id);
			if (st == null)
				return;

			String msgLit = JSONObject.quote(message);
			String js = "(function(){try{if(window.luanti&&luanti._trigger){luanti._trigger(" + msgLit + ");}}catch(e){}})();";
			if (Build.VERSION.SDK_INT >= 19) {
				st.webView.evaluateJavascript(js, null);
			} else {
				st.webView.loadUrl("javascript:" + js);
			}
		});
	}

	public void htmlview_navigate(String id, String url) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.get(id);
			if (st != null)
				st.webView.loadUrl(url);
		});
	}

	public void htmlview_inject(String id, String js) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.get(id);
			if (st == null)
				return;
			if (Build.VERSION.SDK_INT >= 19) {
				st.webView.evaluateJavascript(js, null);
			} else {
				st.webView.loadUrl("javascript:" + js);
			}
		});
	}

	public void htmlview_pipe(String fromId, String toId) {
		activity.runOnUiThread(() -> pipes.put(fromId, toId));
	}

	public void htmlview_capture(String id, int width, int height) {
		activity.runOnUiThread(() -> {
			HtmlViewState st = views.get(id);
			if (st == null)
				return;
			capturePngToNativeOnUiThread(id, st, width, height);
		});
	}

	public void htmlview_bind_texture(String id, int width, int height, int fps) {
		activity.runOnUiThread(() -> {
			HtmlViewState st0 = getOrCreate(id);

			int f = fps <= 0 ? 10 : fps;
			int intervalMs = Math.max(16, 1000 / Math.max(1, f));
			int w = Math.max(0, width);
			int h = Math.max(0, height);

			int offW = w > 0 ? w : 256;
			int offH = h > 0 ? h : 256;

			TextureLoop existing = textureLoops.get(id);
			if (existing != null) {
				existing.width = w;
				existing.height = h;
				existing.intervalMs = intervalMs;
				if (existing.offscreenApplied) {
					try {
						HtmlViewState st = views.get(id);
						if (st != null && st.container.getLayoutParams() instanceof FrameLayout.LayoutParams) {
							FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) st.container.getLayoutParams();
							lp.width = Math.max(1, offW);
							lp.height = Math.max(1, offH);
							st.container.setLayoutParams(lp);
						}
					} catch (Exception ignored) {
					}
				}
				handler.removeCallbacks(existing.runnable);
				handler.post(existing.runnable);
				return;
			}

			TextureLoop loop = new TextureLoop();
			loop.width = w;
			loop.height = h;
			loop.intervalMs = intervalMs;

			try {
				int vis = st0.container.getVisibility();
				if (vis != View.VISIBLE) {
					loop.offscreenApplied = true;
					loop.prevVisibility = vis;
					loop.prevAlpha = st0.container.getAlpha();
					loop.prevLayerType = st0.webView.getLayerType();
					if (st0.container.getLayoutParams() instanceof FrameLayout.LayoutParams) {
						FrameLayout.LayoutParams prev = (FrameLayout.LayoutParams) st0.container.getLayoutParams();
						loop.prevWidth = prev.width;
						loop.prevHeight = prev.height;
						loop.prevLeftMargin = prev.leftMargin;
						loop.prevTopMargin = prev.topMargin;
						loop.prevRightMargin = prev.rightMargin;
						loop.prevBottomMargin = prev.bottomMargin;
						loop.prevGravity = prev.gravity;
					}

					st0.container.setVisibility(View.VISIBLE);
					st0.container.setAlpha(0.0f);
					st0.container.setEnabled(false);
					st0.container.setClickable(false);
					st0.webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);

					FrameLayout.LayoutParams lp;
					if (st0.container.getLayoutParams() instanceof FrameLayout.LayoutParams) {
						lp = (FrameLayout.LayoutParams) st0.container.getLayoutParams();
					} else {
						lp = new FrameLayout.LayoutParams(1, 1);
					}
					lp.gravity = Gravity.TOP | Gravity.START;
					lp.width = Math.max(1, offW);
					lp.height = Math.max(1, offH);
					lp.leftMargin = -10000;
					lp.topMargin = -10000;
					lp.rightMargin = 0;
					lp.bottomMargin = 0;
					st0.container.setLayoutParams(lp);
					setDragEnabled(st0, false);
				}
			} catch (Exception ignored) {
			}

			try {
				int[] ph = new int[] { 0xFF101014, 0xFF101014, 0xFF101014, 0xFF101014 };
				nativeOnHTMLTextureFrame(id, 2, 2, ph);
			} catch (Exception ignored) {
			}

			loop.runnable = new Runnable() {
				@Override
				public void run() {
					TextureLoop l = textureLoops.get(id);
					if (l == null)
						return;
					HtmlViewState st = views.get(id);
					if (st != null)
						captureTextureToNativeOnUiThread(id, st, l);
					handler.postDelayed(this, l.intervalMs);
				}
			};

			textureLoops.put(id, loop);
			handler.post(loop.runnable);
		});
	}

	public void htmlview_unbind_texture(String id) {
		activity.runOnUiThread(() -> {
			TextureLoop loop = textureLoops.remove(id);
			if (loop != null) {
				try {
					handler.removeCallbacks(loop.runnable);
				} catch (Exception ignored) {
				}
				try {
					if (loop.bmp != null) {
						loop.bmp.recycle();
						loop.bmp = null;
					}
				} catch (Exception ignored) {
				}
				loop.canvas = null;
				loop.pixels = null;

				if (loop.offscreenApplied) {
					try {
						HtmlViewState st = views.get(id);
						if (st != null) {
							st.webView.setLayerType(loop.prevLayerType, null);
							if (st.container.getLayoutParams() instanceof FrameLayout.LayoutParams) {
								FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) st.container.getLayoutParams();
								lp.width = loop.prevWidth;
								lp.height = loop.prevHeight;
								lp.leftMargin = loop.prevLeftMargin;
								lp.topMargin = loop.prevTopMargin;
								lp.rightMargin = loop.prevRightMargin;
								lp.bottomMargin = loop.prevBottomMargin;
								lp.gravity = loop.prevGravity;
								st.container.setLayoutParams(lp);
							}
							st.container.setAlpha(loop.prevAlpha);
							st.container.setEnabled(true);
							st.container.setClickable(true);
							st.container.setVisibility(loop.prevVisibility);
						}
					} catch (Exception ignored) {
					}
				}
			}
		});
	}

	private void capturePngToNativeOnUiThread(String id, HtmlViewState st, int width, int height) {
		WebView wv = st.webView;

		int w = width > 0 ? width : wv.getWidth();
		int h = height > 0 ? height : wv.getHeight();
		if (w <= 0)
			w = st.container.getWidth();
		if (h <= 0)
			h = st.container.getHeight();
		if (w <= 0)
			w = 256;
		if (h <= 0)
			h = 256;

		w = Math.min(w, 2048);
		h = Math.min(h, 2048);

		try {
			Bitmap bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
			Canvas canvas = new Canvas(bmp);
			int vw = wv.getWidth();
			int vh = wv.getHeight();
			if (vw > 0 && vh > 0) {
				float sx = w / (float) vw;
				float sy = h / (float) vh;
				canvas.save();
				canvas.scale(sx, sy);
				wv.draw(canvas);
				canvas.restore();
			} else {
				int ws = View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY);
				int hs = View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY);
				wv.measure(ws, hs);
				wv.layout(0, 0, w, h);
				wv.draw(canvas);
			}

			ByteArrayOutputStream out = new ByteArrayOutputStream();
			bmp.compress(Bitmap.CompressFormat.PNG, 100, out);
			bmp.recycle();
			String b64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
			nativeOnHTMLCapture(id, b64);
		} catch (Exception ignored) {
		}
	}

	private void captureTextureToNativeOnUiThread(String id, HtmlViewState st, TextureLoop loop) {
		WebView wv = st.webView;

		int w = loop.width > 0 ? loop.width : wv.getWidth();
		int h = loop.height > 0 ? loop.height : wv.getHeight();
		if (w <= 0)
			w = st.container.getWidth();
		if (h <= 0)
			h = st.container.getHeight();
		if (w <= 0)
			w = 256;
		if (h <= 0)
			h = 256;

		w = Math.min(w, 2048);
		h = Math.min(h, 2048);

		try {
			if (loop.bmp == null || loop.bmp.getWidth() != w || loop.bmp.getHeight() != h) {
				if (loop.bmp != null)
					loop.bmp.recycle();
				loop.bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
				loop.canvas = new Canvas(loop.bmp);
				loop.pixels = new int[w * h];
			}

			Canvas canvas = loop.canvas;
			if (canvas == null)
				return;

			canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);

			int vw = wv.getWidth();
			int vh = wv.getHeight();
			if (vw > 0 && vh > 0) {
				float sx = w / (float) vw;
				float sy = h / (float) vh;
				canvas.save();
				canvas.scale(sx, sy);
				wv.draw(canvas);
				canvas.restore();
			} else {
				int ws = View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY);
				int hs = View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY);
				wv.measure(ws, hs);
				wv.layout(0, 0, w, h);
				wv.draw(canvas);
			}

			if (loop.pixels == null || loop.pixels.length < w * h)
				loop.pixels = new int[w * h];
			loop.bmp.getPixels(loop.pixels, 0, w, 0, 0, w, h);
			nativeOnHTMLTextureFrame(id, w, h, loop.pixels);
		} catch (Exception ignored) {
		}
	}

	private HtmlViewState getOrCreate(String id) {
		HtmlViewState existing = views.get(id);
		if (existing != null)
			return existing;

		String host = "luanti-" + shortHashHex(id) + ".local";
		String baseUrl = "https://" + host + "/";

		FrameLayout container = new FrameLayout(activity);
		container.setVisibility(View.GONE);
		container.setClipToPadding(false);
		container.setClipChildren(false);

		WebView wv = new WebView(activity);
		wv.setBackgroundColor(Color.TRANSPARENT);

		HtmlViewState st = new HtmlViewState(id, host, baseUrl, container, wv);

		wv.setWebViewClient(new LocalContentClient(st));
		wv.setWebChromeClient(new WebChromeClient() {
			@Override
			public void onPermissionRequest(final PermissionRequest request) {
				activity.runOnUiThread(() -> {
					try {
						request.grant(request.getResources());
					} catch (Exception ignored) {
					}
				});
			}

			@Override
			public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
				try {
					callback.invoke(origin, true, false);
				} catch (Exception ignored) {
				}
			}
		});

		WebSettings settings = wv.getSettings();
		settings.setJavaScriptEnabled(true);
		settings.setDomStorageEnabled(true);
		settings.setMediaPlaybackRequiresUserGesture(false);
		settings.setJavaScriptCanOpenWindowsAutomatically(true);
		settings.setAllowContentAccess(true);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
		}

		wv.addJavascriptInterface(new LuantiBridge(id), "luanti");

		FrameLayout.LayoutParams wvlp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
		wvlp.gravity = Gravity.TOP | Gravity.START;
		container.addView(wv, wvlp);

		View dragBar = new View(activity);
		dragBar.setVisibility(View.GONE);
		dragBar.setBackgroundColor(0x33000000);
		FrameLayout.LayoutParams barlp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dpToPx(36));
		barlp.gravity = Gravity.TOP;
		container.addView(dragBar, barlp);
		st.dragBar = dragBar;
		setupDrag(st);

		FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
		lp.gravity = Gravity.TOP | Gravity.START;
		lp.leftMargin = 0;
		lp.topMargin = 0;
		root.addView(container, lp);

		views.put(id, st);
		return st;
	}

	private void setupDrag(HtmlViewState st) {
		st.dragBar.setOnTouchListener((v, ev) -> {
			if (!st.dragEnabled || st.lastFullscreen)
				return false;
			if (!(st.container.getLayoutParams() instanceof FrameLayout.LayoutParams))
				return false;
			FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) st.container.getLayoutParams();

			switch (ev.getActionMasked()) {
				case MotionEvent.ACTION_DOWN:
					st.dragStartRawX = ev.getRawX();
					st.dragStartRawY = ev.getRawY();
					st.dragStartLeft = lp.leftMargin;
					st.dragStartTop = lp.topMargin;
					return true;
				case MotionEvent.ACTION_MOVE:
					float dx = ev.getRawX() - st.dragStartRawX;
					float dy = ev.getRawY() - st.dragStartRawY;
					int newLeft = Math.round(st.dragStartLeft + dx);
					int newTop = Math.round(st.dragStartTop + dy);
					applyDragPosition(st, newLeft, newTop);
					return true;
				case MotionEvent.ACTION_UP:
				case MotionEvent.ACTION_CANCEL:
					return true;
			}
			return false;
		});
	}

	private void applyDragPosition(HtmlViewState st, int left, int top) {
		if (!(st.container.getLayoutParams() instanceof FrameLayout.LayoutParams))
			return;
		FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) st.container.getLayoutParams();

		int rootW = root.getWidth();
		int rootH = root.getHeight();
		if (rootW <= 0)
			rootW = activity.getResources().getDisplayMetrics().widthPixels;
		if (rootH <= 0)
			rootH = activity.getResources().getDisplayMetrics().heightPixels;

		int w = st.container.getWidth();
		int h = st.container.getHeight();
		if (w <= 0)
			w = lp.width;
		if (h <= 0)
			h = lp.height;
		if (w <= 0 || h <= 0)
			return;

		int safeL = 0;
		int safeT = 0;
		int safeR = rootW;
		int safeB = rootH;

		if (st.lastSafeArea) {
			WindowInsetsCompat wi = ViewCompat.getRootWindowInsets(root);
			if (wi != null) {
				Insets insets = wi.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
				safeL = insets.left;
				safeT = insets.top;
				safeR = rootW - insets.right;
				safeB = rootH - insets.bottom;
			}
		}

		int maxLeft = safeR - w;
		int maxTop = safeB - h;
		int clampedLeft = st.lastSafeArea ? clamp(left, safeL, maxLeft) : clamp(left, 0, rootW - w);
		int clampedTop = st.lastSafeArea ? clamp(top, safeT, maxTop) : clamp(top, 0, rootH - h);

		lp.leftMargin = Math.max(0, clampedLeft);
		lp.topMargin = Math.max(0, clampedTop);
		st.container.setLayoutParams(lp);
	}

	private void setDragEnabled(HtmlViewState st, boolean enabled) {
		st.dragEnabled = enabled;
		st.dragBar.setVisibility(enabled ? View.VISIBLE : View.GONE);
	}

	private void setBorderRadiusPx(HtmlViewState st, float radiusPx) {
		st.borderRadiusPx = radiusPx;
		if (Build.VERSION.SDK_INT < 21)
			return;

		if (radiusPx <= 0.0f) {
			st.container.setClipToOutline(false);
			st.container.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
			return;
		}

		st.container.setOutlineProvider(new ViewOutlineProvider() {
			@Override
			public void getOutline(View view, Outline outline) {
				int w = view.getWidth();
				int h = view.getHeight();
				if (w <= 0 || h <= 0)
					return;
				outline.setRoundRect(0, 0, w, h, st.borderRadiusPx);
			}
		});
		st.container.setClipToOutline(true);
		st.container.invalidateOutline();
	}

	private static int clamp(int v, int min, int max) {
		if (max < min)
			return min;
		return Math.max(min, Math.min(max, v));
	}

	private int dpToPx(int dp) {
		return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, activity.getResources().getDisplayMetrics()));
	}

	private static String normalizeEntry(String entry) {
		String e = (entry == null || entry.trim().isEmpty()) ? "index.html" : entry.trim();
		while (e.startsWith("/"))
			e = e.substring(1);
		if (e.endsWith("/"))
			e = e + "index.html";
		return e;
	}

	private static String shortHashHex(String s) {
		try {
			MessageDigest md = MessageDigest.getInstance("SHA-256");
			byte[] d = md.digest(s.getBytes(StandardCharsets.UTF_8));
			StringBuilder sb = new StringBuilder();
			for (int i = 0; i < d.length && sb.length() < 16; i++) {
				sb.append(String.format(Locale.ROOT, "%02x", d[i]));
			}
			return sb.toString();
		} catch (Exception e) {
			return "0000000000000000";
		}
	}

	private static String injectBridge(String html) {
		String bridge = "<script>(function(){var _native=window.luanti;window.luanti={};luanti._messageCallbacks=[];luanti.on_message=function(cb){if(typeof cb==='function'){luanti._messageCallbacks.push(cb);}};luanti._trigger=function(msg){for(var i=0;i<luanti._messageCallbacks.length;i++){try{luanti._messageCallbacks[i](msg);}catch(e){}}};luanti.send=function(msg){try{if(_native&&_native.send){_native.send(String(msg));}}catch(e){}};})();</script>";
		if (html == null)
			return bridge;

		String lower = html.toLowerCase(Locale.ROOT);
		int head = lower.indexOf("<head");
		if (head >= 0) {
			int end = html.indexOf('>', head);
			if (end >= 0)
				return html.substring(0, end + 1) + bridge + html.substring(end + 1);
		}
		int htmlTag = lower.indexOf("<html");
		if (htmlTag >= 0) {
			int end = html.indexOf('>', htmlTag);
			if (end >= 0)
				return html.substring(0, end + 1) + bridge + html.substring(end + 1);
		}
		return bridge + html;
	}

	private static byte[] readAllBytes(File f) throws Exception {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		try (InputStream in = new FileInputStream(f)) {
			byte[] buf = new byte[8192];
			int n;
			while ((n = in.read(buf)) > 0) {
				out.write(buf, 0, n);
			}
		}
		return out.toByteArray();
	}

	private static String guessMimeType(String relPath) {
		String p = relPath.toLowerCase(Locale.ROOT);
		int dot = p.lastIndexOf('.');
		String ext = (dot >= 0) ? p.substring(dot + 1) : "";
		if (ext.equals("wasm"))
			return "application/wasm";
		if (ext.equals("mjs"))
			return "application/javascript";
		String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
		if (mime != null)
			return mime;
		if (ext.equals("js"))
			return "application/javascript";
		if (ext.equals("json"))
			return "application/json";
		if (ext.equals("svg"))
			return "image/svg+xml";
		return "application/octet-stream";
	}

	private static String guessEncoding(String mime) {
		if (mime == null)
			return null;
		String m = mime.toLowerCase(Locale.ROOT);
		if (m.startsWith("text/"))
			return "utf-8";
		if (m.contains("javascript") || m.contains("json") || m.contains("xml") || m.contains("svg"))
			return "utf-8";
		return null;
	}

	private static boolean isUnderRoot(File rootDir, File f) {
		try {
			String rootPath = rootDir.getCanonicalPath();
			String filePath = f.getCanonicalPath();
			if (!rootPath.endsWith(File.separator))
				rootPath += File.separator;
			return filePath.startsWith(rootPath);
		} catch (Exception ignored) {
			return false;
		}
	}

	private WebResourceResponse serveFromExternal(HtmlViewState st, Uri url) {
		if (st.externalRootDir == null || st.externalEntry == null)
			return null;
		if (url == null)
			return null;
		if (!"https".equals(url.getScheme()))
			return null;
		if (url.getHost() == null || !url.getHost().equals(st.host))
			return null;

		String path = url.getPath();
		if (path == null || path.isEmpty() || path.equals("/"))
			path = "/" + st.externalEntry;

		while (path.startsWith("/"))
			path = path.substring(1);

		if (path.contains(".."))
			return null;

		File rootDir = new File(st.externalRootDir);
		File target = new File(rootDir, path);
		if (!isUnderRoot(rootDir, target))
			return null;

		try {
			if (target.isDirectory()) {
				target = new File(target, "index.html");
				if (!isUnderRoot(rootDir, target))
					return null;
			}
			if (!target.exists())
				return null;

			String mime = guessMimeType(path);
			String encoding = guessEncoding(mime);

			if (mime.startsWith("text/html")) {
				String html = new String(readAllBytes(target), StandardCharsets.UTF_8);
				String injected = injectBridge(html);
				byte[] bytes = injected.getBytes(StandardCharsets.UTF_8);
				WebResourceResponse resp = new WebResourceResponse("text/html", "utf-8", new ByteArrayInputStream(bytes));
				if (Build.VERSION.SDK_INT >= 21) {
					Map<String, String> headers = new HashMap<>();
					headers.put("Access-Control-Allow-Origin", "*");
					resp.setResponseHeaders(headers);
				}
				return resp;
			}

			InputStream in = new FileInputStream(target);
			WebResourceResponse resp = new WebResourceResponse(mime, encoding, in);
			if (Build.VERSION.SDK_INT >= 21) {
				Map<String, String> headers = new HashMap<>();
				headers.put("Access-Control-Allow-Origin", "*");
				resp.setResponseHeaders(headers);
			}
			return resp;
		} catch (Exception ignored) {
			return null;
		}
	}

	private class LocalContentClient extends WebViewClient {
		private final HtmlViewState st;

		LocalContentClient(HtmlViewState st) {
			this.st = st;
		}

		@Override
		public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
			try {
				return serveFromExternal(st, request != null ? request.getUrl() : null);
			} catch (Exception ignored) {
				return null;
			}
		}

		@Override
		public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
			try {
				return serveFromExternal(st, url != null ? Uri.parse(url) : null);
			} catch (Exception ignored) {
				return null;
			}
		}
	}

	private static class TextureLoop {
		int width;
		int height;
		int intervalMs;
		Runnable runnable;
		Bitmap bmp;
		Canvas canvas;
		int[] pixels;

		boolean offscreenApplied;
		int prevVisibility;
		float prevAlpha;
		int prevLayerType;
		int prevWidth;
		int prevHeight;
		int prevLeftMargin;
		int prevTopMargin;
		int prevRightMargin;
		int prevBottomMargin;
		int prevGravity;
	}

	private static class HtmlViewState {
		final String id;
		final String host;
		final String baseUrl;
		final FrameLayout container;
		final WebView webView;

		View dragBar;
		boolean dragEnabled;
		float borderRadiusPx;

		String externalRootDir;
		String externalEntry;

		boolean lastSafeArea = true;
		boolean lastFullscreen = false;

		float dragStartRawX;
		float dragStartRawY;
		int dragStartLeft;
		int dragStartTop;

		HtmlViewState(String id, String host, String baseUrl, FrameLayout container, WebView webView) {
			this.id = id;
			this.host = host;
			this.baseUrl = baseUrl;
			this.container = container;
			this.webView = webView;
		}
	}

	@Keep
	class LuantiBridge {
		private final String viewId;

		LuantiBridge(String id) {
			this.viewId = id;
		}

		@JavascriptInterface
		public void send(String message) {
			String pipeTo = pipes.get(viewId);
			if (pipeTo != null) {
				htmlview_send(pipeTo, message);
				return;
			}
			nativeOnHTMLMessage(viewId, message);
		}
	}

	private static native void nativeOnHTMLMessage(String id, String message);
	private static native void nativeOnHTMLCapture(String id, String pngBase64);
	private static native void nativeOnHTMLTextureFrame(String id, int width, int height, int[] argb);
}
