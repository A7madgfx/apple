# رفيق الصلاة — Prayer Companion (iOS)

تطبيق iOS أصلي بلغة Swift/SwiftUI، عربي بالكامل وباتجاه RTL، بهوية بصرية أسود/أصفر.

## ⚠️ حالة هذا التسليم (اقرأ أولاً)

تم إنشاء هذا الكود على بيئة **Windows بدون Xcode/macOS**. كل الملفات كتابة يدوية كاملة
(Swift حقيقي، ليس Mockup)، لكن **لم يتم فتحها أو بناؤها فعليًا في Xcode بعد** — لا توجد
بيئة macOS متاحة هنا للقيام بذلك. الخطوات التالية إلزامية على جهاز Mac قبل الاستخدام:

1. أنشئ مشروع iOS App جديد في Xcode (SwiftUI, Swift, iOS 17+).
2. احذف الملفات الافتراضية (`ContentView.swift` إلخ) وأضف مجلدات `App/ Core/ Features/
   Resources/ Tests/` من هذا التسليم بالسحب والإفلات (Add Files to "PrayerCompanion"…)،
   مع التأكد من إضافة `Resources/Azkar` و `Resources/Quran` كـ **Folder References**
   (مجلد أزرق، وليس Group) حتى يعمل `Bundle.main.url(forResource:withExtension:subdirectory:)`.
3. فعّل القدرات التالية من تبويب Signing & Capabilities:
   - Background Modes → Audio, AirPlay, and Picture in Picture
   - (اختياري) Background Modes → Background fetch / Background processing
4. أضف صوت أذان افتراضي باسم `default_adhan.mp3` داخل `Resources/Audio/` (غير مُرفق هنا
   لأسباب حقوق الملكية — أضف ملفًا تملك حقوقه أو أذانًا مرخصًا للاستخدام الحر).
5. ابنِ المشروع (⌘B) وشغّل الاختبارات (⌘U) وأصلح أي أخطاء ترجمة ناتجة عن اختلاف نسخة
   Xcode/SDK لديك، ثم شغّل السيناريو الكامل من `35. Final Acceptance Flow` يدويًا على جهاز حقيقي
   (الكاميرا/الموقع لا يعملان على المحاكي بشكل كامل).

## البنية

```
App/                      نقطة الدخول + AppState (Composition Root) + Info.plist
Core/Models/               نماذج الصلاة، القرآن، الأذكار
Core/Services/             LocationService, PrayerScheduleService, PrayerAudioManager,
                            NotificationManager, CameraService,
                            PrayerMatRecognitionService, QuranService, AzkarService,
                            SettingsStore, PermissionManager
Core/Utilities/             PrayerTimeCalculator (حساب فلكي كامل، بدون شبكة)
Core/Extensions/            الألوان/الخطوط + تنسيق التاريخ العربي
Features/…                  Onboarding, Home, PrayerAlarm, PrayerMatVerification,
                            Quran, Azkar, Settings
Resources/Azkar/*.json      أذكار الصباح والمساء، منسوخة حرفيًا من islambook.com
Resources/Quran/surah_index.json  فهرس السور (بيانات وصفية ثابتة فقط، وليست نص القرآن)
Tests/                      اختبارات وحدة لحساب الأوقات والإعدادات والأذكار
```

## حدود نظام iOS الموثّقة (لا يتم الالتفاف عليها)

1. **لا يمكن لتطبيق منهي تمامًا (Terminated) أن يُشغَّل تلقائيًا ليبدأ تشغيل صوت طويل**
   من الصفر. نظام iOS لا يمنح أي API عامًا لذلك. الحل المعتمد هنا: تشغيل الصوت يتم بواسطة
   `PrayerAudioManager` أثناء كون التطبيق في المقدمة أو في الخلفية "حيًا" ضمن Background
   Mode الخاص بالصوت (وهو آلية مدعومة رسميًا من Apple لاستمرار تشغيل صوت كان يعمل بالفعل،
   وليس لبدء تشغيل جديد من العدم بعد إنهاء التطبيق). إشعارات النظام تُستخدم للتوعية والجدولة
   فقط، وصوت الإشعار المحلي نفسه محدود بمقاطع صوتية قصيرة حسب قيود نظام iOS، وليس أذانًا كاملًا.
2. **لا يوجد نموذج Core ML مخصص مُدرَّب على "سجادات الصلاة"** مرفق مع هذا المشروع (لا يوجد
   نموذج كهذا مضمّن في iOS، وتدريب نموذج مخصص خارج نطاق هذا التسليم). البديل المُطبَّق:
   `PrayerMatRecognitionService` يجمع بين تصنيف Vision العام على الجهاز
   (`VNClassifyImageRequest`) وقواعد حتمية لجودة الصورة (ضبابية/إضاءة/تغطية الإطار) لرفض
   الصور الواضحة الخطأ. هذا هو أقوى حل ممكن بواجهات Apple الرسمية فقط وبدون شبكة، لكنه **غير
   دقيق بنسبة 100%** — إن رغبتم بدقة أعلى، درّبوا نموذج Core ML مخصص بـ Create ML وزوّدوا
   الخدمة به.
3. **محتوى القرآن**: تم بناء `QuranService` ليجلب نص السور/الصفحات من surahquran.com عند
   أول استخدام ويخزّنه محليًا (Cache) بحيث تعمل القراءة لاحقًا بدون إنترنت. لم يُنسخ نص
   القرآن الكامل (6236 آية) يدويًا داخل هذا المستودع؛ فهرس السور (الأرقام/الأسماء/عدد
   الآيات) فقط مضمّن كبيانات وصفية ثابتة. **يجب التحقق من محلل HTML البسيط
   (`QuranHTMLParser`) مقابل بنية الصفحة الفعلية لـ surahquran.com وتعديله عند الحاجة**،
   لأن بنية HTML للمواقع تتغير دون إشعار.
4. **الأذكار**: تم جلب نصوص أذكار الصباح (31 عنصرًا) والمساء (30 عنصرًا) فعليًا من
   islambook.com حرفيًا (النص وعدد التكرار) وتضمينها في `Resources/Azkar/*.json` — لا حاجة
   لشبكة لعرضها.

## التشغيل

بعد اتباع خطوات الإعداد أعلاه: أول تشغيل → Onboarding عربي → طلب إذن الموقع ثم الإشعارات
بشكل منفصل → الشاشة الرئيسية بمواقيت اليوم → عند دخول وقت أي صلاة مفعّلة + دقيقتين يبدأ
تشغيل الصوت تلقائيًا وتظهر شاشة التنبيه بدون زر "إيقاف" → "قمت للصلاة" → الكاميرا →
التحقق على الجهاز → نجاح ⇒ يتوقف الصوت، أو فشل ⇒ يبقى الصوت يعمل مع خيار إعادة المحاولة.
