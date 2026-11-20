package com.kittyrescue.services;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.view.View;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.*;
import com.godot.game.BuildConfig;
import com.google.android.play.core.review.ReviewManagerFactory;
import com.google.android.play.core.appupdate.*;
import com.google.android.play.core.install.model.*;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import java.util.*;

public final class KittyServices extends GodotPlugin {
    private AdsController ads;
    private CoffeeBilling billing;
    private AppUpdateManager updates;
    public KittyServices(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "KittyServices"; }
    @Override public Set<SignalInfo> getPluginSignals() { return new HashSet<>(Arrays.asList(new SignalInfo("service_event", String.class, String.class))); }
    void event(String kind, String payload) { runOnRenderThread(() -> emitSignal("service_event", kind, payload)); }
    Activity activity() { return getActivity(); }
    @UsedByGodot public boolean ads_removed() { return activity().getSharedPreferences("kitty_purchases", 0).getBoolean("remove_ads", false); }
    void setAdsRemoved(boolean owned) {
        activity().getSharedPreferences("kitty_purchases", 0).edit().putBoolean("remove_ads", owned).apply();
        runOnUiThread(() -> { if (ads != null) ads.setAdsRemoved(owned); });
        event("ads_removed", owned ? "true" : "false");
    }
    @UsedByGodot public boolean ads_configured() { return BuildConfig.KITTY_ADS_CONFIGURED; }
    @UsedByGodot public String read_ad_units() {
        try (java.io.InputStream in = getActivity().getAssets().open("kitty_ad_units.json")) { java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream(); byte[] buffer = new byte[1024]; int n; while ((n=in.read(buffer))!=-1) out.write(buffer,0,n); return out.toString("UTF-8"); }
        catch (Exception ignored) { return "{}"; }
    }
    @UsedByGodot public void initialize_ads(String units) { runOnUiThread(() -> {
        if (!BuildConfig.KITTY_ADS_CONFIGURED) { event("ad_failed", "configuration"); return; }
        if (ads == null) { ads = new AdsController(this); ads.initialize(units); }
    }); }
    @UsedByGodot public void set_home(boolean home) { runOnUiThread(() -> { if (ads != null) ads.setHome(home); }); }
    @UsedByGodot public void stop_ads() { runOnUiThread(() -> { if (ads != null) ads.disable(); }); }
    @UsedByGodot public void show_rewarded(String token) { runOnUiThread(() -> { if (ads != null) ads.reward(token); else event("ad_failed", "rewarded"); }); }
    @UsedByGodot public void show_interstitial() { runOnUiThread(() -> { if (ads != null) ads.interstitial(); }); }
    @UsedByGodot public void privacy_options() { runOnUiThread(() -> com.google.android.ump.UserMessagingPlatform.showPrivacyOptionsForm(getActivity(), error -> {})); }
    @UsedByGodot public void start_commerce() { runOnUiThread(() -> { if (billing == null) { billing = new CoffeeBilling(this); billing.connect(); } }); }
    @UsedByGodot public void buy_product(String id) { runOnUiThread(() -> { if (billing != null) billing.buyProduct(id); else event("message", "Google Play billing is not ready."); }); }
    @UsedByGodot public void buy_coffee() { buy_product("coins_1000"); }
    @UsedByGodot public void buy_remove_ads() { event("message", "Only coin packs are available in this build."); }
    @UsedByGodot public void restore_purchases() { runOnUiThread(() -> { if (billing != null) billing.restore(); else event("message", "Google Play billing is not ready."); }); }
    private String storeUrl() { return "https://play.google.com/store/apps/details?id=" + getActivity().getPackageName(); }
    @UsedByGodot public void share_game() { runOnUiThread(() -> {
        Intent send = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "Eat small, grow big, and hunt mice in Kitty Hunt! " + storeUrl());
        getActivity().startActivity(Intent.createChooser(send, "Share Kitty Hunt"));
    }); }
    @UsedByGodot public void rate_game() { runOnUiThread(() -> {
        com.google.android.play.core.review.ReviewManager manager = ReviewManagerFactory.create(getActivity());
        manager.requestReviewFlow().addOnSuccessListener(info -> manager.launchReviewFlow(getActivity(), info)).addOnFailureListener(error -> openStore());
    }); }
    private void openStore() { try { getActivity().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + getActivity().getPackageName()))); } catch (Exception e) { getActivity().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(storeUrl()))); } }
    @UsedByGodot public void check_updates() { runOnUiThread(() -> {
        if (updates == null) {
            updates = AppUpdateManagerFactory.create(getActivity());
            updates.registerListener(state -> { if (state.installStatus() == InstallStatus.DOWNLOADED) event("update_downloaded", ""); });
        }
        updates.getAppUpdateInfo().addOnSuccessListener(info -> {
            if (info.installStatus() == InstallStatus.DOWNLOADED) event("update_downloaded", "");
            else if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE && info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) event("update_available", "");
        });
    }); }
    @UsedByGodot public void start_update() { runOnUiThread(() -> {
        if (updates == null) return;
        updates.getAppUpdateInfo().addOnSuccessListener(info -> {
            if (info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                try { updates.startUpdateFlowForResult(info, getActivity(), AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(), 447); }
                catch (Exception e) { event("message", "Open Google Play to update Kitty Rescue."); }
            }
        });
    }); }
    @UsedByGodot public void sign_in_play_games() { runOnUiThread(() -> {
        try {
            PlayGamesSdk.initialize(getActivity());
            GamesSignInClient signInClient = PlayGames.getGamesSignInClient(getActivity());
            signInClient.isAuthenticated().addOnCompleteListener(task -> {
                boolean isAuth = task.isSuccessful() && task.getResult() != null && task.getResult().isAuthenticated();
                if (isAuth) {
                    PlayGames.getPlayersClient(getActivity()).getCurrentPlayer()
                        .addOnSuccessListener(player -> event("play_games_signed_in", player.getDisplayName()))
                        .addOnFailureListener(e -> event("play_games_signed_in", "Player"));
                } else {
                    signInClient.signIn().addOnCompleteListener(signTask -> {
                        boolean ok = signTask.isSuccessful() && signTask.getResult() != null && signTask.getResult().isAuthenticated();
                        if (ok) {
                            PlayGames.getPlayersClient(getActivity()).getCurrentPlayer()
                                .addOnSuccessListener(player -> event("play_games_signed_in", player.getDisplayName()))
                                .addOnFailureListener(e -> event("play_games_signed_in", "Player"));
                        } else {
                            event("play_games_sign_in_failed", "");
                        }
                    });
                }
            });
        } catch (Exception e) {
            event("play_games_sign_in_failed", e.getMessage() != null ? e.getMessage() : "");
        }
    }); }
    @UsedByGodot public void complete_update() { runOnUiThread(() -> { if (updates != null) updates.completeUpdate(); }); }
    @UsedByGodot public boolean notifications_allowed() { return Build.VERSION.SDK_INT < 33 || getActivity().checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED; }
    @UsedByGodot public void set_challenge_notification(boolean enabled, int nextCoins) { runOnUiThread(() -> {
        getActivity().getSharedPreferences("kitty_notifications",0).edit().putBoolean("enabled",enabled).putInt("coins",nextCoins).apply();
        if (enabled && !notifications_allowed() && Build.VERSION.SDK_INT >= 33) getActivity().requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS}, 448);
        ChallengeReceiver.schedule(getActivity());
    }); }
    @UsedByGodot public boolean take_daily_launch() {
        boolean result = getActivity().getIntent().getBooleanExtra("daily_challenge", false);
        getActivity().getIntent().removeExtra("daily_challenge");
        return result;
    }
    @Override public void onMainRequestPermissionsResult(int request, String[] permissions, int[] results) {
        if (request == 448 && (results.length == 0 || results[0] != android.content.pm.PackageManager.PERMISSION_GRANTED)) {
            getActivity().getSharedPreferences("kitty_notifications",0).edit().putBoolean("enabled",false).apply();
            ChallengeReceiver.schedule(getActivity());
            event("notification_denied", "Daily Challenge notifications remain off because permission was not granted.");
        }
    }
    @Override public void onMainDestroy() { if (ads != null) ads.disable(); if (billing != null) billing.close(); }
    @Override public void onMainResume() { runOnUiThread(() -> { if (billing != null) billing.restore(false); }); }
}
