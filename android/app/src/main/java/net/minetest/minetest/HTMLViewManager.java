package net.minetest.minetest;

import android.graphics.Color;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.Keep;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Locale;

@Keep
@SuppressWarnings({"unused", "WeakerAccess"})
public class HTMLViewManager {
	private static final String BASE_URL = "https://luanti.local/";
	private static final int CENTER_SENTINEL = Integer.MIN_VALUE;

	private final GameActivity activity;
	private final ViewGroup root;
	private final HashMap<String, WebView> webViews = new HashMap<>();

	public HTMLViewManager(GameActivity activity, ViewGroup root) {
		this.activity = activity;
		this.root = root;
	}

	public void shutdown() {
		activity.runOnUiThread(() -> {
			for (WebView wv : webViews.values()) {
				try {
					root.removeView(wv);
				} catch (Exception ignored) {
				}
				try {
					wv.destroy();
				} catch (Exception ignored) {
				}
			}
			webViews.clear();
		});
	}

	public void htmlview_run(String id, String html) {
		activity.runOnUiThread(() -> {
			WebView wv = getOrCreate(id);
			String injected = injectBridge(html);
			wv.loadDataWithBaseURL(BASE_URL + id + "/", injected, "text/html", "utf-8", null);
		});
	}

	public void htmlview_stop(String id) {
		activity.runOnUiThread(() -> {
			WebView wv = webViews.remove(id);
			if (wv == null)
				return;
			try {
				root.removeView(wv);
			} catch (Exception ignored) {
			}
			try {
				wv.destroy();
			} catch (Exception ignored) {
			}
		});
	}

	public void htmlview_display(String id, int x, int y, int width, int height,
								boolean visible, boolean fullscreen, boolean safe_area) {
		activity.runOnUiThread(() -> {
			WebView wv = webViews.get(id);
			if (wv == null)
				return;

			wv.setVisibility(visible ? View.VISIBLE : View.GONE);
			if (!visible)
				return;

			int rootW = root.getWidth();
			int rootH = root.getHeight();
			if (rootW <= 0)
				rootW = activity.getResources().getDisplayMetrics().widthPixels;
			if (rootH <= 0)
				rootH = activity.getResources().getDisplayMetrics().heightPixels;

			int insetLeft = 0, insetTop = 0, insetRight = 0, insetBottom = 0;
			if (safe_area) {
				WindowInsetsCompat wi = ViewCompat.getRootWindowInsets(root);
				if (wi != null) {
					Insets insets = wi.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
					insetLeft = insets.left;
					insetTop = insets.top;
					insetRight = insets.right;
					insetBottom = insets.bottom;
				}
			}

			int safeL = insetLeft;
			int safeT = insetTop;
			int safeR = rootW - insetRight;
			int safeB = rootH - insetBottom;

			int availW = Math.max(0, safeR - safeL);
			int availH = Math.max(0, safeB - safeT);

			int finalW;
			int finalH;
			int finalX;
			int finalY;

			int marginR = safe_area ? insetRight : 0;
			int marginB = safe_area ? insetBottom : 0;

			if (fullscreen) {
				finalW = ViewGroup.LayoutParams.MATCH_PARENT;
				finalH = ViewGroup.LayoutParams.MATCH_PARENT;
				finalX = safe_area ? safeL : 0;
				finalY = safe_area ? safeT : 0;
			} else {
				finalW = Math.max(1, width);
				finalH = Math.max(1, height);

				if (safe_area) {
					if (finalW > availW) {
						finalW = availW;
					}
					if (finalH > availH) {
						finalH = availH;
					}
				}
				finalW = Math.max(1, finalW);
				finalH = Math.max(1, finalH);

				finalX = x;
				finalY = y;

				if (finalX == CENTER_SENTINEL) {
					finalX = safeL + Math.max(0, (availW - finalW) / 2);
				}
				if (finalY == CENTER_SENTINEL) {
					finalY = safeT + Math.max(0, (availH - finalH) / 2);
				}

				if (safe_area) {
					finalX = clamp(finalX, safeL, safeR - finalW);
					finalY = clamp(finalY, safeT, safeB - finalH);
				}
			}

			FrameLayout.LayoutParams lp;
			if (wv.getLayoutParams() instanceof FrameLayout.LayoutParams) {
				lp = (FrameLayout.LayoutParams) wv.getLayoutParams();
			} else {
				lp = new FrameLayout.LayoutParams(1, 1);
			}
			lp.gravity = Gravity.TOP | Gravity.START;

			if (finalW == ViewGroup.LayoutParams.MATCH_PARENT)
				lp.width = ViewGroup.LayoutParams.MATCH_PARENT;
			else
				lp.width = finalW;
			if (finalH == ViewGroup.LayoutParams.MATCH_PARENT)
				lp.height = ViewGroup.LayoutParams.MATCH_PARENT;
			else
				lp.height = finalH;

			lp.leftMargin = Math.max(0, finalX);
			lp.topMargin = Math.max(0, finalY);
			lp.rightMargin = fullscreen ? marginR : 0;
			lp.bottomMargin = fullscreen ? marginB : 0;
			wv.setLayoutParams(lp);
		});
	}

	public void htmlview_send(String id, String message) {
		activity.runOnUiThread(() -> {
			WebView wv = webViews.get(id);
			if (wv == null)
				return;

			String msgLit = JSONObject.quote(message);
			String js = "(function(){try{if(window.luanti&&luanti._trigger){luanti._trigger(" + msgLit + ");}}catch(e){}})();";
			if (Build.VERSION.SDK_INT >= 19) {
				wv.evaluateJavascript(js, null);
			} else {
				wv.loadUrl("javascript:" + js);
			}
		});
	}

	private WebView getOrCreate(String id) {
		WebView existing = webViews.get(id);
		if (existing != null)
			return existing;

		WebView wv = new WebView(activity);
		wv.setBackgroundColor(Color.TRANSPARENT);
		wv.setWebViewClient(new WebViewClient());
		wv.setWebChromeClient(new AutoGrantWebChromeClient());

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
		wv.setVisibility(View.GONE);

		FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
		lp.gravity = Gravity.TOP | Gravity.START;
		lp.leftMargin = 0;
		lp.topMargin = 0;
		root.addView(wv, lp);

		webViews.put(id, wv);
		return wv;
	}

	private static int clamp(int v, int min, int max) {
		if (max < min)
			return min;
		return Math.max(min, Math.min(max, v));
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

	private static class AutoGrantWebChromeClient extends WebChromeClient {
		@Override
		public void onPermissionRequest(final PermissionRequest request) {
			try {
				request.grant(request.getResources());
			} catch (Exception ignored) {
			}
		}

		@Override
		public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
			try {
				callback.invoke(origin, true, false);
			} catch (Exception ignored) {
			}
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
			nativeOnHTMLMessage(viewId, message);
		}
	}

	private static native void nativeOnHTMLMessage(String id, String message);
}
