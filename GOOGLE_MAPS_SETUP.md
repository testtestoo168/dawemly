# إعداد Google Maps API Key في مشروع رصد

## الـ API Key
```
AIzaSyB-CkusFlHFxJujo_GagT1kSNoQtmCq630
```

## الملفات اللي اتعدلت:

### 1. Android (جاهز)
الملف: `android/app/src/main/AndroidManifest.xml`
- تم إضافة `<meta-data>` بالـ API Key
- تم إضافة permissions للـ Location والـ Biometric

### 2. iOS (جاهز)
الملف: `ios/Runner/AppDelegate.swift`
- تم إضافة `GMSServices.provideAPIKey()` 
- ⚠️ محتاج تضيف في `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>التطبيق يحتاج الموقع لتسجيل الحضور</string>
```

### 3. Web (جاهز)  
الملف: `web/index.html`
- تم إضافة `<script>` لـ Google Maps JavaScript API

## ملاحظات:
- لو عندك `android/app/src/main/AndroidManifest.xml` قديم، انسخ السطر ده فيه:
```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="AIzaSyB-CkusFlHFxJujo_GagT1kSNoQtmCq630"/>
```
- لو عندك `web/index.html` قديم، ضيف قبل `</head>`:
```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyB-CkusFlHFxJujo_GagT1kSNoQtmCq630"></script>
```
