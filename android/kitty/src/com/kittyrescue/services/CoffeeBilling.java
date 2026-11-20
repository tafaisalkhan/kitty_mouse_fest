package com.kittyrescue.services;

import com.android.billingclient.api.*;
import java.util.*;

// Coffee is consumed; Remove Ads is acknowledged and retained permanently.
final class CoffeeBilling implements PurchasesUpdatedListener {
    private final KittyServices owner;
    private BillingClient client;
    private final Map<String, ProductDetails> products = new HashMap<>();
    private final Map<String, ProductDetails.OneTimePurchaseOfferDetails> offers = new HashMap<>();
    private final Set<String> processing = new HashSet<>();
    CoffeeBilling(KittyServices owner) { this.owner = owner; }
    void connect() {
        client = BillingClient.newBuilder(owner.activity()).setListener(this).enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()).enableAutoServiceReconnection().build();
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(BillingResult result) { if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) { query(); restore(false); } else owner.event("billing_unavailable", ""); }
            @Override public void onBillingServiceDisconnected() { owner.event("billing_unavailable", ""); }
        });
    }
    private void query() {
        List<QueryProductDetailsParams.Product> items = new ArrayList<>();
        for (String id : new String[]{"cofee", "remove_ads"}) items.add(QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(BillingClient.ProductType.INAPP).build());
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(items).build(), (result, details) -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) { owner.event("billing_unavailable", ""); return; }
            for (ProductDetails product : details.getProductDetailsList()) {
                List<ProductDetails.OneTimePurchaseOfferDetails> list = product.getOneTimePurchaseOfferDetailsList();
                if (list == null || list.isEmpty()) continue;
                products.put(product.getProductId(), product);
                offers.put(product.getProductId(), list.get(0));
                owner.event(product.getProductId().equals("cofee") ? "coffee_price" : "remove_ads_price", list.get(0).getFormattedPrice());
            }
        });
    }
    void buy() { buy("cofee"); }
    void buyRemoveAds() { if (owner.ads_removed()) { owner.event("message", "Ads are already removed."); return; } buy("remove_ads"); }
    private void buy(String id) {
        ProductDetails product = products.get(id);
        ProductDetails.OneTimePurchaseOfferDetails offer = offers.get(id);
        if (product == null || offer == null || client == null || !client.isReady()) { owner.event("message", "This purchase is not available from Google Play yet."); return; }
        BillingFlowParams.ProductDetailsParams item = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).setOfferToken(offer.getOfferToken()).build();
        BillingResult result = client.launchBillingFlow(owner.activity(), BillingFlowParams.newBuilder().setProductDetailsParamsList(Collections.singletonList(item)).build());
        if (result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) restore(true);
        else if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) owner.event("message", "Google Play could not open checkout.");
    }
    @Override public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        if (result.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) for (Purchase purchase : purchases) finish(purchase);
        else if (result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) restore(true);
        else if (result.getResponseCode() != BillingClient.BillingResponseCode.USER_CANCELED) owner.event("message", "Purchase could not be completed.");
    }
    private void finish(Purchase purchase) {
        boolean removeAds = purchase.getProducts().contains("remove_ads");
        boolean coffee = purchase.getProducts().contains("cofee");
        if (!removeAds && !coffee) return;
        if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) { owner.event("message", "Your purchase is pending in Google Play. It unlocks when payment completes."); return; }
        if (purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) return;
        if (removeAds) {
            owner.setAdsRemoved(true);
            if (purchase.isAcknowledged() || !processing.add(purchase.getPurchaseToken())) return;
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(), result -> {
                processing.remove(purchase.getPurchaseToken());
                if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) owner.event("message", "Ads are removed. Google Play confirmation will retry when the game resumes.");
            });
        } else if (processing.add(purchase.getPurchaseToken())) {
            client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(), (result, token) -> {
                processing.remove(token);
                if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) owner.event("coffee_purchased", "cofee");
                else owner.event("message", "Coffee payment received. Google Play will retry delivery when you reopen the game.");
            });
        }
    }
    void restore() { restore(true); }
    void restore(boolean notify) {
        if (client == null || !client.isReady()) { if (notify) owner.event("message", "Google Play billing is not ready. Please try again."); return; }
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(), (result, purchases) -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) { if (notify) owner.event("message", "Google Play could not restore purchases. Please try again."); return; }
            boolean owned = false;
            for (Purchase purchase : purchases) if (purchase.getProducts().contains("remove_ads") && purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED) owned = true;
            owner.setAdsRemoved(owned);
            for (Purchase purchase : purchases) finish(purchase);
            if (notify) owner.event("restore_complete", owned ? "Remove Ads restored. Banner and between-level ads are disabled." : "No Remove Ads purchase was found for this Google Play account. Pending purchases were checked.");
        });
    }
    void close() { if (client != null) client.endConnection(); }
}
