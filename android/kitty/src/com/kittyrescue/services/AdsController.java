package com.kittyrescue.services;

import android.view.*;
import android.widget.FrameLayout;
import com.google.android.gms.ads.*;
import com.google.android.gms.ads.interstitial.*;
import com.google.android.gms.ads.rewarded.*;
import com.google.android.ump.*;
import org.json.JSONObject;

final class AdsController {
    private final KittyServices owner;
    private JSONObject ids;
    private AdView banner;
    private InterstitialAd interstitial;
    private RewardedAd rewarded;
    private boolean disabled, home = true, started, adsRemoved, bannerLoaded;
    AdsController(KittyServices owner) { this.owner = owner; adsRemoved = owner.ads_removed(); }
    void setAdsRemoved(boolean value) {
        boolean changed = adsRemoved != value;
        adsRemoved = value;
        if (value) { interstitial = null; if (banner != null) { banner.destroy(); if (banner.getParent() instanceof ViewGroup) ((ViewGroup)banner.getParent()).removeView(banner); banner = null; } }
        else if (changed && started && !disabled) { loadBanner(); loadInterstitial(); }
    }
    void initialize(String text) {
        try { ids = new JSONObject(text); for (String key : new String[]{"ADMOB_BANNER_ID","ADMOB_INTERSTITIAL_ID","ADMOB_REWARDED_ID"}) { String v = ids.getString(key); if (!v.matches("ca-app-pub-\\d{16}/\\d{10}") || v.contains("3940256099942544")) throw new Exception(); } }
        catch (Exception e) { fail("configuration"); return; }
        ConsentInformation consent = UserMessagingPlatform.getConsentInformation(owner.activity());
        consent.requestConsentInfoUpdate(owner.activity(), new ConsentRequestParameters.Builder().build(), () ->
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(owner.activity(), error -> { if (consent.canRequestAds()) start(); else fail("consent"); }), error -> { if (consent.canRequestAds()) start(); else fail("consent"); });
    }
    private void start() {
        if (started || disabled) return;
        started = true;
        MobileAds.initialize(owner.activity(), status -> owner.activity().runOnUiThread(() -> { if (disabled) return; loadBanner(); loadInterstitial(); loadRewarded(); }));
    }
    private String unit(String key) { return ids.optString(key, ""); }
    private void fail(String format) { if (disabled || (adsRemoved && (format.equals("banner") || format.equals("interstitial")))) return; disable(); owner.event("ad_failed", format); }
    void disable() { disabled = true; bannerLoaded = false; interstitial = null; rewarded = null; if (banner != null) { banner.destroy(); if (banner.getParent() instanceof ViewGroup) ((ViewGroup)banner.getParent()).removeView(banner); banner = null; } }
    void setHome(boolean value) { home = value; if (banner != null) banner.setVisibility(value && bannerLoaded && !disabled && !adsRemoved ? View.VISIBLE : View.GONE); }
    private void loadBanner() {
        if (disabled || adsRemoved) return;
        bannerLoaded = false;
        banner = new AdView(owner.activity());
        banner.setVisibility(View.GONE);
        banner.setAdUnitId(unit("ADMOB_BANNER_ID"));
        int width = (int)(owner.activity().getResources().getDisplayMetrics().widthPixels / owner.activity().getResources().getDisplayMetrics().density);
        banner.setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(owner.activity(), width));
        banner.setAdListener(new AdListener() {
            @Override public void onAdLoaded() { if (!disabled) { bannerLoaded = true; setHome(home); owner.event("ad_loaded", "banner"); } }
            @Override public void onAdFailedToLoad(LoadAdError error) { fail("banner"); }
        });
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        owner.activity().addContentView(banner, params);
        setHome(home);
        banner.loadAd(new AdRequest.Builder().build());
    }
    private void loadInterstitial() {
        if (disabled || adsRemoved) return;
        InterstitialAd.load(owner.activity(), unit("ADMOB_INTERSTITIAL_ID"), new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override public void onAdLoaded(InterstitialAd ad) { if (!disabled && !adsRemoved) { interstitial = ad; owner.event("ad_loaded", "interstitial"); } }
            @Override public void onAdFailedToLoad(LoadAdError error) { fail("interstitial"); }
        });
    }
    private void loadRewarded() {
        if (disabled) return;
        RewardedAd.load(owner.activity(), unit("ADMOB_REWARDED_ID"), new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override public void onAdLoaded(RewardedAd ad) { if (!disabled) { rewarded = ad; owner.event("ad_loaded", "rewarded"); } }
            @Override public void onAdFailedToLoad(LoadAdError error) { fail("rewarded"); }
        });
    }
    void interstitial() {
        if (disabled || adsRemoved || interstitial == null) return;
        InterstitialAd ad = interstitial; interstitial = null;
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override public void onAdDismissedFullScreenContent() { loadInterstitial(); }
            @Override public void onAdFailedToShowFullScreenContent(AdError error) { fail("interstitial"); }
        });
        ad.show(owner.activity());
    }
    void reward(String token) {
        if (disabled) { owner.event("ad_failed", "rewarded"); return; }
        if (rewarded == null) { owner.event("reward_not_ready", token); return; }
        RewardedAd ad = rewarded; rewarded = null;
        final boolean[] earned = {false};
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override public void onAdDismissedFullScreenContent() { if (!earned[0]) owner.event("reward_closed", token); loadRewarded(); }
            @Override public void onAdFailedToShowFullScreenContent(AdError error) { fail("rewarded"); }
        });
        ad.show(owner.activity(), item -> { earned[0] = true; owner.event("reward_earned", token); });
    }
}
