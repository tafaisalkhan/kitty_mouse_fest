package com.kittyrescue.services;

import com.android.billingclient.api.*;
import java.util.*;

// Only consumable coin packs (coins_1000, coins_2000, coins_3000) are mapped for Google Play Billing.
final class CoffeeBilling implements PurchasesUpdatedListener {
    private static final Map<String, Integer> COIN_PACKS = new LinkedHashMap<>();
    static {
        COIN_PACKS.put("coins_1000", 1000);
        COIN_PACKS.put("coins_2000", 2000);
        COIN_PACKS.put("coins_3000", 3000);
    }

    private final KittyServices owner;
    private BillingClient client;
    private final Map<String, ProductDetails> products = new HashMap<>();
    private final Map<String, ProductDetails.OneTimePurchaseOfferDetails> offers = new HashMap<>();
    private final Set<String> processing = new HashSet<>();

    CoffeeBilling(KittyServices owner) { this.owner = owner; }

    void connect() {
        client = BillingClient.newBuilder(owner.activity())
                .setListener(this)
                .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                .enableAutoServiceReconnection()
                .build();
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(BillingResult result) {
                if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    query();
                    restore(false);
                } else {
                    owner.event("billing_unavailable", "");
                }
            }
            @Override public void onBillingServiceDisconnected() { owner.event("billing_unavailable", ""); }
        });
    }

    private void query() {
        List<QueryProductDetailsParams.Product> items = new ArrayList<>();
        for (String id : COIN_PACKS.keySet()) {
            items.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build());
        }
        for (String id : new String[]{"remove_ads", "cofee"}) {
            items.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build());
        }
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(items).build(), (result, details) -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                owner.event("billing_unavailable", "");
                return;
            }
            for (ProductDetails product : details.getProductDetailsList()) {
                List<ProductDetails.OneTimePurchaseOfferDetails> list = product.getOneTimePurchaseOfferDetailsList();
                if (list == null || list.isEmpty()) continue;
                products.put(product.getProductId(), product);
                offers.put(product.getProductId(), list.get(0));
                if ("remove_ads".equals(product.getProductId())) {
                    owner.event("remove_ads_price", list.get(0).getFormattedPrice());
                } else if ("cofee".equals(product.getProductId())) {
                    owner.event("coffee_price", list.get(0).getFormattedPrice());
                } else {
                    owner.event("pack_price", product.getProductId() + ":" + list.get(0).getFormattedPrice());
                }
            }
        });
    }

    void buyCoffee() {
        launchCheckout("cofee");
    }

    void buyRemoveAds() {
        if (owner.ads_removed()) {
            owner.event("message", "Ads are already removed.");
            return;
        }
        launchCheckout("remove_ads");
    }

    void buyProduct(String id) {
        if (!COIN_PACKS.containsKey(id)) {
            owner.event("message", "This coin pack is not available.");
            return;
        }
        launchCheckout(id);
    }

    private void launchCheckout(String id) {
        ProductDetails product = products.get(id);
        ProductDetails.OneTimePurchaseOfferDetails offer = offers.get(id);
        if (product == null || offer == null || client == null || !client.isReady()) {
            owner.event("message", "Google Play test/store billing is not ready yet.");
            return;
        }
        BillingFlowParams.ProductDetailsParams item = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(product)
                .setOfferToken(offer.getOfferToken())
                .build();
        BillingResult result = client.launchBillingFlow(owner.activity(),
                BillingFlowParams.newBuilder().setProductDetailsParamsList(Collections.singletonList(item)).build());
        if (result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) restore(true);
        else if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) owner.event("message", "Google Play could not open checkout.");
    }

    @Override public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        if (result.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (Purchase purchase : purchases) finish(purchase);
        } else if (result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            restore(true);
        } else if (result.getResponseCode() != BillingClient.BillingResponseCode.USER_CANCELED) {
            owner.event("message", "Purchase could not be completed.");
        }
    }

    private void finish(Purchase purchase) {
        boolean isRemoveAds = purchase.getProducts().contains("remove_ads");
        boolean isCoffee = purchase.getProducts().contains("cofee");
        String matchedId = null;
        for (String id : COIN_PACKS.keySet()) {
            if (purchase.getProducts().contains(id)) {
                matchedId = id;
                break;
            }
        }
        if (!isRemoveAds && !isCoffee && matchedId == null) return;
        if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) {
            owner.event("message", "Your purchase is pending in Google Play. It unlocks when payment completes.");
            return;
        }
        if (purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) return;
        if (isRemoveAds) {
            owner.setAdsRemoved(true);
            if (purchase.isAcknowledged() || !processing.add(purchase.getPurchaseToken())) return;
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(), result -> {
                processing.remove(purchase.getPurchaseToken());
            });
            return;
        }
        if (!processing.add(purchase.getPurchaseToken())) return;
        if (isCoffee) {
            client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(), (result, token) -> {
                processing.remove(token);
                if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    owner.event("coffee_purchased", "cofee");
                } else {
                    owner.event("message", "Coffee payment received. Google Play will retry delivery when you reopen the game.");
                }
            });
            return;
        }
        final String productId = matchedId;
        final int coins = COIN_PACKS.get(matchedId);
        client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(), (result, token) -> {
            processing.remove(token);
            if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                owner.event("coins_purchased", productId + ":" + coins);
            } else {
                owner.event("message", "Payment received. Google Play will retry coin delivery when you reopen the game.");
            }
        });
    }

    void restore() { restore(true); }

    void restore(boolean notify) {
        if (client == null || !client.isReady()) {
            if (notify) owner.event("message", "Google Play billing is not ready. Please try again.");
            return;
        }
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(), (result, purchases) -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                if (notify) owner.event("message", "Google Play could not check purchases. Please try again.");
                return;
            }
            boolean owned = false;
            for (Purchase purchase : purchases) {
                if (purchase.getProducts().contains("remove_ads") && purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED) owned = true;
            }
            owner.setAdsRemoved(owned);
            for (Purchase purchase : purchases) finish(purchase);
            if (notify) owner.event("restore_complete", owned ? "Remove Ads restored and pending coin purchases checked." : "Pending Google Play purchases were checked.");
        });
    }

    void close() { if (client != null) client.endConnection(); }
}
