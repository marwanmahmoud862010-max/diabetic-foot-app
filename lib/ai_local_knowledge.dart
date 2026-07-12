import 'language_service.dart';

class AiLocalKnowledge {
  static String findResponse(String query) {
    final q = query.toLowerCase().trim();
    final isRTL = LanguageService.isRTL;

    // Greetings
    if (_matchesAny(q, ['مرحبا', 'اهلا', 'السلام', 'هلا', 'هاي', 'hello', 'hi', 'hey', 'bonjour', 'salut', 'marhaba'])) {
      return isRTL
          ? 'وعليكم السلام! 👋 أنا مساعد StepGuard الذكي. اسألني عن القدم السكري، الوقاية، الفحوصات، أو أي حاجة.'
          : 'Hello! 👋 I\'m the StepGuard AI assistant. Ask me about diabetic foot care, prevention, tests, or anything!';
    }

    // What is StepGuard
    if (_matchesAny(q, ['what is stepguard', 'stepguard', 'step guard', 'ايه هو', 'ازاي', 'شرح', 'التطبيق ده', 'function', 'app'])) {
      return isRTL
          ? 'StepGuard هو تطبيق متكامل للعناية بالقدم السكري. بيساعدك تفحص قدمك يومياً عن طريق:\n\n'
              '• 🩺 **الفحص اليومي** — 3 أسئلة عن التنميل والوجع والجروح\n'
              '• 🌡️ **قياس الحرارة** — قارن درجة حرارة قدميك (الفرق >2.2°C = التهاب)\n'
              '• 👆 **فحص اللمس** — اختبر الإحساس في أصابعك\n'
              '• 📸 **تحليل الصور** — صورتك بتتحلل بالذكاء الاصطناعي\n'
              '• 📊 **تقييم الخطر** — حسب تصنيف IWGDF العالمي\n'
              '• 📋 **التقارير** — تقارير PDF + مشاركة مع الدكتور\n'
              'كل ده عشان تقلل خطر القرحة والبتر بنسبة تصل لـ 85%!'
          : 'StepGuard is a complete diabetic foot care app. It helps you check your feet daily:\n\n'
              '• 🩺 **Daily Checkup** — 3 questions about numbness, pain, wounds\n'
              '• 🌡️ **Temperature Test** — compare both feet (diff >2.2°C = inflammation)\n'
              '• 👆 **Touch Test** — check sensation in your toes\n'
              '• 📸 **Photo Analysis** — AI-powered image analysis\n'
              '• 📊 **Risk Assessment** — based on IWGDF classification\n'
              '• 📋 **Reports** — PDF reports + WhatsApp sharing\n'
              'All to reduce ulcer and amputation risk by up to 85%!';
    }

    // Statistics
    if (_matchesAny(q, ['statistics', 'stat', 'احصائيات', 'احصا', 'نسبة', 'عدد', 'إحصائيات', 'data', 'prevalence', 'كم', 'شائع'])) {
      return isRTL
          ? '📊 **إحصائيات مهمة عن القدم السكري:**\n\n'
              '• 537 مليون شخص حول العالم عندهم سكري (IDF 2021)\n'
              '• **15-25%** من مرضى السكري هيعانو من قرحة القدم طول حياتهم\n'
              '• كل **20 ثانية**، بيتم بتر طرف في مكان ما في العالم due to diabetes\n'
              '• قرحة القدم بتسبب **85%** من حالات البتر\n'
              '• **50-70%** نسبة الوفيات خلال 5 سنين بعد البتر (أخطر من سرطان الثدي والبروستاتا!)\n'
              '• العناية المنتظمة بالقدم **بتقلل البتر 45-85%**\n'
              '• **50%** من مرضى السكري بيصابوا بالاعتلال العصبي مع الوقت\n'
              '• **واحد من كل 3** مرضى سكري فوق 50 سنة عنده مرض شرايين طرفية'
          : '📊 **Important Diabetic Foot Statistics:**\n\n'
              '• 537 million adults worldwide have diabetes (IDF 2021)\n'
              '• **15-25%** of people with diabetes will develop a foot ulcer\n'
              '• Every **20 seconds**, a limb is amputated due to diabetes worldwide\n'
              '• Foot ulcers precede **85%** of diabetes-related amputations\n'
              '• **50-70%** 5-year mortality rate after amputation (worse than breast or prostate cancer!)\n'
              '• Proper foot care **reduces amputation risk by 45-85%**\n'
              '• **50%** of people with diabetes develop neuropathy over time\n'
              '• **1 in 3** diabetics over 50 has peripheral artery disease';
    }

    // Prevention
    if (_matchesAny(q, ['prevent', 'نصايح', 'نصائح', 'وقاية', 'تجنب', 'تعليمات', 'avoid', 'protect', 'خطر', 'ازاي احمي', 'recommendation'])) {
      return isRTL
          ? '🛡️ **نصائح ذهبية للوقاية من مشاكل القدم السكري:**\n\n'
              '1. **لا تمشي حافي** أبداً — حتى في البيت\n'
              '2. **افحص جوه الحذاء** قبل ما تلبسه\n'
              '3. **اغسل قدمك يومياً** بمية دافية وجفف كويس بين الأصابع\n'
              '4. **قص الأظافر بشكل مستقيم** — مش منحني\n'
              '5. **افحص قدمك بالمرآة** كل يوم — عشان تشوف تحت\n'
              '6. **رطب الجلد** عشان يفضل ناعم (بس مش بين الأصابع)\n'
              '7. **ارتدي أحذية مناسبة** — مريحة ومغلقة\n'
              '8. **ضبط السكر في الدم** — حجر الأساس\n'
              '9. **ممنوع التدخين** — بيضر الدورة الدموية\n'
              '10. **راجع الدكتور فوراً** لو ظهر جرح أو احمرار أو تورم\n\n'
              '📌 كل النصائح دي موجودة في شاشة "النصائح" في التطبيق!'
          : '🛡️ **Golden Prevention Tips for Diabetic Foot:**\n\n'
              '1. **Never walk barefoot** — even indoors\n'
              '2. **Check inside shoes** before wearing\n'
              '3. **Wash feet daily** with warm water, dry well between toes\n'
              '4. **Cut nails straight across** — not curved\n'
              '5. **Check feet with a mirror** daily — to see the bottom\n'
              '6. **Moisturize skin** but not between toes\n'
              '7. **Wear proper shoes** — comfortable and closed\n'
              '8. **Control blood sugar** — the foundation\n'
              '9. **No smoking** — harms circulation\n'
              '10. **See a doctor immediately** if wound, redness, or swelling appears\n\n'
              '📌 All tips are in the "Prevention Tips" section of the app!';
    }

    // Risk factors
    if (_matchesAny(q, ['risk factor', 'عوامل', 'خطورة', 'خطر', 'معرض', 'عرضة', 'susceptible', 'أسباب', 'مين', 'who'])) {
      return isRTL
          ? '⚠️ **عوامل الخطورة للقدم السكري:**\n\n'
              '• **الاعتلال العصبي** (فقدان الإحساس) — أخطر عامل\n'
              '• **ضعف الدورة الدموية** (مرض الشرايين الطرفية)\n'
              '• **تشوهات القدم** (أصابع مطرقية، ورم ملتهب)\n'
              '• **تاريخ سابق بقرحة أو بتر**\n'
              '• **ارتفاع السكر المزمن** (HbA1c عالي)\n'
              '• **مدة السكري الطويلة** (>10 سنين)\n'
              '• **التدخين**\n'
              '• **أمراض الكلى**\n'
              '• **ضعف البصر**\n'
              '• **الأحذية غير المناسبة**\n\n'
              '📌 في شاشة "تقييم الخطر" تقدر تحسب مستواك حسب تصنيف IWGDF!'
          : '⚠️ **Diabetic Foot Risk Factors:**\n\n'
              '• **Neuropathy** (loss of sensation) — the biggest risk\n'
              '• **Poor circulation** (peripheral artery disease)\n'
              '• **Foot deformities** (hammertoes, bunions, Charcot foot)\n'
              '• **Previous ulcer or amputation**\n'
              '• **Chronic high blood sugar** (high HbA1c)\n'
              '• **Long diabetes duration** (>10 years)\n'
              '• **Smoking**\n'
              '• **Kidney disease**\n'
              '• **Poor vision**\n'
              '• **Improper footwear**\n\n'
              '📌 Use the "Risk Assessment" screen to calculate your risk per IWGDF!';
    }

    // Temperature test
    if (_matchesAny(q, ['temperature', 'حرارة', 'درجة', 'temp', 'حرا', 'سخونة', 'قاس درجة'])) {
      return isRTL
          ? '🌡️ **اختبار درجة الحرارة:**\n\n'
              'تقدر تقيس درجة حرارة قدمك في 3 مناطق:\n'
              '• **الكعب** (Heel)\n'
              '• **منتصف القدم** (Midfoot)\n'
              '• **الأصابع** (Toes)\n\n'
              '⚠️ **القاعدة الذهبية:** لو الفرق بين القدم اليمين والشمال أكتر من **2.2°C** — ده دليل التهاب!\n\n'
              '📌 افتح شاشة "Temperature" في التطبيق وجرب!'
          : '🌡️ **Temperature Test:**\n\n'
              'Measure your foot temperature in 3 regions:\n'
              '• **Heel**\n'
              '• **Midfoot**\n'
              '• **Toes**\n\n'
              '⚠️ **The golden rule:** If the difference between right and left foot exceeds **2.2°C** — this indicates inflammation!\n\n'
              '📌 Open the "Temperature" screen in the app and try it!';
    }

    // Touch test
    if (_matchesAny(q, ['touch', 'monofilament', 'لمس', 'حس', 'إحساس', 'عصب', 'تنميل', 'mono'])) {
      return isRTL
          ? '👆 **اختبار اللمس (Monofilament):**\n\n'
              'بيعملوا الدكتور أو مقدم رعاية مدرب. بيستخدم **خيط أحادي 10g** والمس 3 نقاط في كل قدم:\n'
              '• **إصبع 1** (البركة)\n'
              '• **إصبع 3** (الوسطاني)\n'
              '• **إصبع 5** (الخنصر)\n\n'
              'لو مش حاسس بلمسة الخيط في نقطة — ده دليل على **الاعتلال العصبي**.\n\n'
              '📌 استخدم شاشة "Touch Test" في التطبيق!'
          : '👆 **Touch Test (Monofilament):**\n\n'
              'Done by a doctor or trained caregiver using a **10g monofilament**. Touch 3 points on each foot:\n'
              '• **Toe 1** (big toe)\n'
              '• **Toe 3** (middle toe)\n'
              '• **Toe 5** (little toe)\n\n'
              'If you can\'t feel the filament at a point — this indicates **neuropathy**.\n\n'
              '📌 Use the "Touch Test" screen in the app!';
    }

    // Photo analysis
    if (_matchesAny(q, ['photo', 'تصوير', 'صورة', 'كاميرا', 'تحليل', 'ai', 'image', 'صور', 'كشف', 'آي آي'])) {
      return isRTL
          ? '📸 **تحليل الصور بالذكاء الاصطناعي:**\n\n'
              'تقدر تصور قدمك والتطبيق بيحللها ويDiscover:\n'
              '• 🔴 **احمرار** — دليل التهاب\n'
              '• 🔵 **ازرقاق** — دليل ضعف الدورة الدموية\n'
              '• ⚫ **بقع غامقة** — ممكن جرح أو نخر\n'
              '• ⚪ **شحوب** — نقص تدفق الدم\n\n'
              'التطبيق بيستخدم تقنيتين:\n'
              '1. **Gemini AI** — تحليل متقدم (فيه حصة محدودة)\n'
              '2. **تحليل محلي** — بيحلل البيكسلز مباشرة بدون نت\n\n'
              '📌 كمان فيه مقارنة الصور (قديم vs جديد) عشان تلاحظ التغيير!'
          : '📸 **AI Photo Analysis:**\n\n'
              'Take a photo of your foot and the app analyzes it to detect:\n'
              '• 🔴 **Redness** — inflammation\n'
              '• 🔵 **Blueness** — poor circulation\n'
              '• ⚫ **Dark spots** — possible wound or necrosis\n'
              '• ⚪ **Paleness** — reduced blood flow\n\n'
              'The app uses two methods:\n'
              '1. **Gemini AI** — advanced cloud analysis (limited quota)\n'
              '2. **Local analysis** — pixel-based, works offline\n\n'
              '📌 Also includes photo comparison (old vs new) to track changes!';
    }

    // Checkup
    if (_matchesAny(q, ['checkup', 'فحص', 'يومي', 'فحص يومي', 'daily', 'اسئلة', 'أسئلة', 'q_'])) {
      return isRTL
          ? '🩺 **الفحص اليومي:**\n\n'
              '3 أسئلة بسيطة عشان تقيم حالة قدمك:\n'
              '1. **هل بتشعر بتنميل؟** — لا / خفيف / شديد\n'
              '2. **هل بتشعر بوجع أو حرقة؟** — لا / خفيف / شديد\n'
              '3. **هل في جرح أو تغير لون؟** — لا / نعم\n\n'
              'النتيجة:\n'
              '• ✅ **مطمئن** — استمر في العناية\n'
              '• ⚠️ **استشارة دكتور** — لو تنميل شديد أو وجع شديد أو في جرح\n\n'
              '📌 افتح شاشة "Daily Checkup" وجرب!'
          : '🩺 **Daily Checkup:**\n\n'
              '3 simple questions to assess your feet:\n'
              '1. **Do you feel numbness?** — No / Mild / Severe\n'
              '2. **Do you feel pain or burning?** — No / Mild / Severe\n'
              '3. **Is there a wound or color change?** — No / Yes\n\n'
              'Result:\n'
              '• ✅ **Reassuring** — continue your care\n'
              '• ⚠️ **Doctor visit needed** — if severe numbness, severe pain, or wound\n\n'
              '📌 Open the "Daily Checkup" screen and try it!';
    }

    // IWGDF Classification
    if (_matchesAny(q, ['iwgdf', 'تصنيف', 'مستوى', 'risk level', 'risk 0', 'risk 1', 'risk 2', 'risk 3', 'category'])) {
      return isRTL
          ? '📊 **تصنيف IWGDF لمخاطر القدم السكري:**\n\n'
              '• **Risk 0** 🟢 — مفيش اعتلال عصبي → فحص سنوي\n'
              '• **Risk 1** 🟡 — اعتلال عصبي بس → فحص كل 6-12 شهر\n'
              '• **Risk 2** 🟠 — اعتلال + ضعف دوران أو تشوه → فحص كل 3-6 شهور\n'
              '• **Risk 3** 🔴 — تاريخ قرحة أو بتر → فحص كل 1-3 شهور + فحص يومي\n\n'
              '📌 استخدم شاشة "Risk Assessment" في التطبيق عشان تحسب مستواك!'
          : '📊 **IWGDF Diabetic Foot Risk Classification:**\n\n'
              '• **Risk 0** 🟢 — No neuropathy → Annual checkup\n'
              '• **Risk 1** 🟡 — Neuropathy only → Check every 6-12 months\n'
              '• **Risk 2** 🟠 — Neuropathy + PAD or deformity → Check every 3-6 months\n'
              '• **Risk 3** 🔴 — History of ulcer or amputation → Check every 1-3 months + daily\n\n'
              '📌 Use the "Risk Assessment" screen to calculate your level!';
    }

    // Wound care
    if (_matchesAny(q, ['wound', 'جرح', 'قرحة', 'تقرح', 'ulcer', 'infection', 'عدوى', 'تورم', 'صديد', 'مصابة', 'علاج'])) {
      return isRTL
          ? '🩹 **العناية بالجروح:**\n\n'
              '⚠️ أي جرح في قدم مريض السكري **حالة طارئة**!\n\n'
              '**إجراءات فورية:**\n'
              '1. **نظف الجرح** بمحلول ملحي أو مية مغلية ومبردة\n'
              '2. **غطي الجرح** بشاش معقم (مش لاصق طبي)\n'
              '3. **خفف الضغط** — متحطش وزنك على القدم\n'
              '4. **راجع الدكتور فوراً** — حتى لو الجرح صغير\n\n'
              '**علامات الخطر:**\n'
              '• 🟡 صديد أو إفرازات\n'
              '• 🔴 احمرار أو سخونة\n'
              '• ⚫ تغير للون الغامق\n'
              '• 🤒 حرارة عالية\n'
              '• 💨 ريحة غير طبيعية\n\n'
              'العلاج المحترف ممكن يشمل:\n'
              '• إزالة الأنسجة الميتة (Debridement)\n'
              '• مضادات حيوية\n'
              '• أحذية تخفيف الضغط\n'
              '• ضبط السكر\n'
              '• وفي الحالات المتقدمة — قسطرة أو جراحة أوعية دموية'
          : '🩹 **Wound Care:**\n\n'
              '⚠️ Any wound on a diabetic foot is a **medical emergency**!\n\n'
              '**Immediate steps:**\n'
              '1. **Clean the wound** with saline or cooled boiled water\n'
              '2. **Cover with sterile gauze** (not adhesive)\n'
              '3. **Offload** — don\'t put weight on that foot\n'
              '4. **See a doctor immediately** — even for small wounds\n\n'
              '**Danger signs:**\n'
              '• 🟡 Pus or discharge\n'
              '• 🔴 Redness or heat\n'
              '• ⚫ Dark color change\n'
              '• 🤒 Fever\n'
              '• 💨 Unusual odor\n\n'
              'Professional treatment may include:\n'
              '• Debridement (removing dead tissue)\n'
              '• Antibiotics\n'
              '• Offloading shoes\n'
              '• Blood sugar control\n'
              '• In severe cases — angioplasty or vascular surgery';
    }

    // Symptoms / Warning signs
    if (_matchesAny(q, ['symptom', 'علامات', 'أعراض', 'اعراض', 'أمارات', 'warning', 'تحذير', 'انتبه', 'notice', 'تلاحظ', 'شوف', 'يتغير'])) {
      return isRTL
          ? '🔍 **الأعراض اللي لازم تراقبها يومياً:**\n\n'
              '• 🔴 **احمرار أو تورم** — التهاب\n'
              '• 🔵 **ازرقاق أو شحوب** — ضعف الدورة الدموية\n'
              '• ⚫ **بقع سوداء أو زرقاء** — نخر (موت أنسجة)\n'
              '• 🩹 **جروح أو تشققات** — أي جرح صغير خطر\n'
              '• 💧 **بثور أو فقاعات** — ممكن تتحول لقرحة\n'
              '• 🔥 **سخونة في منطقة** — التهاب\n'
              '• 🧊 **برودة في القدم** — نقص تدفق الدم\n'
              '• 🦶 **تغير في شكل القدم** — ممكن قدم شاركوه\n'
              '• 💅 **أظافر غائرة أو فطرية** — مصدر عدوى\n'
              '• 👃 **ريحة غير طبيعية** — علامة عدوى أو نخر\n\n'
              '📌 استخدم شاشة "Photo Analysis" عشان تحلل الصورة بالذكاء الاصطناعي!'
          : '🔍 **Symptoms to Watch Daily:**\n\n'
              '• 🔴 **Redness or swelling** — inflammation\n'
              '• 🔵 **Blueness or paleness** — poor circulation\n'
              '• ⚫ **Black or dark blue spots** — necrosis\n'
              '• 🩹 **Cuts or cracks** — any small wound is dangerous\n'
              '• 💧 **Blisters** — can turn into an ulcer\n'
              '• 🔥 **Heat in one area** — inflammation\n'
              '• 🧊 **Cold foot** — reduced blood flow\n'
              '• 🦶 **Change in foot shape** — possible Charcot foot\n'
              '• 💅 **Ingrown or fungal nails** — infection source\n'
              '• 👃 **Unusual odor** — sign of infection or necrosis\n\n'
              '📌 Use the "Photo Analysis" for AI-powered detection!';
    }

    // Neuropathy
    if (_matchesAny(q, ['neuropathy', 'neuro', 'اعتلال', 'عصبي', 'تنميل', 'نمل', 'وخز', 'حرقان', 'numb', 'burning', 'tingling'])) {
      return isRTL
          ? '🧠 **الاعتلال العصبي السكري:**\n\n'
              'أكثر مضاعفات السكري شيوعاً — بيأثر على **50%** من المرضى.\n\n'
              '**الأعراض:**\n'
              '• تنميل أو فقدان الإحساس\n'
              '• وخز أو حرقان (زي الدبابيس)\n'
              '• وجع حاد أو تقلصات\n'
              '• حساسية شديدة للمس\n'
              '• فقدان التوازن\n\n'
              '**الخطر:** إنك مش حاسس بالجروح فبتتفاقم من غير ما تدري!\n\n'
              '**العلاج:**\n'
              '• التحكم الصارم في السكر\n'
              '• أدوية للألم العصبي\n'
              '• الفحص اليومي للقدم (إلزامي!)\n'
              '• أحذية مناسبة\n\n'
              '📌 استخدم "Touch Test" في التطبيق عشان تكتشف loss of sensation!'
          : '🧠 **Diabetic Neuropathy:**\n\n'
              'The most common diabetes complication — affects **50%** of patients.\n\n'
              '**Symptoms:**\n'
              '• Numbness or reduced sensation\n'
              '• Tingling or burning (pins and needles)\n'
              '• Sharp pain or cramps\n'
              '• Extreme sensitivity to touch\n'
              '• Loss of balance\n\n'
              '**The danger:** You can\'t feel wounds, so they worsen without you knowing!\n\n'
              '**Treatment:**\n'
              '• Strict blood sugar control\n'
              '• Neuropathic pain medications\n'
              '• Daily foot inspection (mandatory!)\n'
              '• Proper footwear\n\n'
              '📌 Use "Touch Test" to detect loss of sensation!';
    }

    // Blood sugar
    if (_matchesAny(q, ['sugar', 'سكر', 'glucose', 'جلوكوز', 'hba1c', 'التراكمي', 'تحكم', 'control', 'مستوى', 'نسبة'])) {
      return isRTL
          ? '💉 **التحكم في سكر الدم:**\n\n'
              'التحكم الجيد في السكر هو **حجر الأساس** للوقاية من مضاعفات القدم.\n\n'
              '**المؤشرات المستهدفة:**\n'
              '• سكر صائم: 80-130 mg/dL\n'
              '• سكر بعد الأكل: <180 mg/dL\n'
              '• HbA1c (التراكمي): <7% (للبالغين)\n\n'
              '**نصيحة:** كل 1% نقص في HbA1c = **40%** تقليل في خطر مضاعفات القدم!\n\n'
              '⚠️ ارتفاع السكر المستمر = ضعف المناعة + بطء التئام الجروح'
          : '💉 **Blood Sugar Control:**\n\n'
              'Good blood sugar control is the **foundation** of preventing foot complications.\n\n'
              '**Target ranges:**\n'
              '• Fasting: 80-130 mg/dL\n'
              '• Post-meal: <180 mg/dL\n'
              '• HbA1c: <7% (for adults)\n\n'
              '**Tip:** Every 1% reduction in HbA1c = **40%** lower risk of foot complications!\n\n'
              '⚠️ Chronic high sugar = weakened immunity + slow wound healing';
    }

    // Shoes / Footwear
    if (_matchesAny(q, ['shoe', 'حذاء', 'جزمة', 'كوتشي', 'boots', 'حذاء', 'footwear', 'لبس', 'socks', 'شراب', 'جوارب'])) {
      return isRTL
          ? '👟 **نصائح الأحذية لمرضى السكري:**\n\n'
              '• **احذيه مغلقة** — مش صنادل أو شبشب\n'
              '• **مقاس مناسب** — مش ضيقة ولا واسعة\n'
              '• **خامه ناعمة** — من جوه مش خشنة أو درزات\n'
              '• **نعل سميك ومبطن** — يخفف الضغط\n'
              '• **افحص جوه الحذاء** قبل اللبس (حصى، دبابيس، إلخ)\n\n'
              '**الشرابات:**\n'
              '• قطن أو صوف (مش نايلون)\n'
              '• بدون درزات (seamless)\n'
              '• مش ضيقة على الكعب\n'
              '• تتغير يومياً'
          : '👟 **Footwear Tips for Diabetics:**\n\n'
              '• **Closed shoes** — not sandals or flip-flops\n'
              '• **Proper fit** — not tight or loose\n'
              '• **Smooth inside** — no rough seams\n'
              '• **Thick padded sole** — to reduce pressure\n'
              '• **Check inside shoes** before wearing (pebbles, pins, etc.)\n\n'
              '**Socks:**\n'
              '• Cotton or wool (not nylon)\n'
              '• Seamless\n'
              '• Not tight around the calf\n'
              '• Changed daily';
    }

    // Foot washing
    if (_matchesAny(q, ['wash', 'غسل', 'استحمام', 'بانيو', 'حمام', 'نظافة', 'clean', 'غسيل', 'بشر'])) {
      return isRTL
          ? '🚿 **طريقة غسل القدم الصحيحة:**\n\n'
              '1. استخدم **مية دافية** (مش سخنة — اختبر الحرارة بإيدك!)\n'
              '2. استخدم صابون معتدل (مش قوي)\n'
              '3. جفف القدم **بلطف** بفوطة ناعمة\n'
              '4. جفف **بين الأصابع** كويس — الرطوبة بتسبب فطريات\n'
              '5. استخدم **كريم مرطب** (مش بين الأصابع)\n'
              '6. افحص القدم كويس بعد الغسيل\n\n'
              '⚠️ **تحذير:** لو حاسس بتنميل، اختبر حرارة المية بمرفقك أو بترمومتر — مش برجلك!'
          : '🚿 **Proper Foot Washing:**\n\n'
              '1. Use **warm water** (not hot — test with your hand!)\n'
              '2. Use mild soap\n'
              '3. **Gently pat dry** with a soft towel\n'
              '4. **Dry between toes** well — moisture causes fungus\n'
              '5. Apply **moisturizer** (not between toes)\n'
              '6. Inspect your foot thoroughly after washing\n\n'
              '⚠️ **Warning:** If you have numbness, test water temperature with your elbow or a thermometer — not your foot!';
    }

    // Nail care
    if (_matchesAny(q, ['nail', 'ظفر', 'ظافر', 'أظافر', 'قص', 'مقلم', 'clipper', 'pedicure'])) {
      return isRTL
          ? '💅 **العناية بالأظافر:**\n\n'
              '• قص الأظافر **بشكل مستقيم** — مش منحني عشان تتجنب الظفر الغائر\n'
              '• استخدم **مقلم أظافر نظيف**\n'
              '• **مبرّد** الحواف الحادة\n'
              '• **لا تقص الجلد** الزايد — ممكن يسبب جرح\n'
              '• لو الأظافر سميكة أو فطرية — راجع الدكتور\n'
              '• **ممنوع الباديكير** في أماكن عامة (خطر عدوى)'
          : '💅 **Nail Care:**\n\n'
              '• Cut nails **straight across** — not curved, to avoid ingrown nails\n'
              '• Use **clean nail clippers**\n'
              '• **File** sharp edges\n'
              '• **Don\'t cut cuticles** — can cause wounds\n'
              '• If nails are thick or fungal — see a doctor\n'
              '• **No public pedicure** — infection risk';
    }

    // Exercise / Activity
    if (_matchesAny(q, ['exercise', 'رياضة', 'تمارين', 'مشي', 'walk', 'حركة', 'نشاط', 'physical', 'active'])) {
      return isRTL
          ? '🏃 **الرياضة والقدم السكري:**\n\n'
              '**مفيد:**\n'
              '• المشي — 30 دقيقة يومياً (بحذاء مناسب طبعاً)\n'
              '• تمارين الكرسي (seated exercises)\n'
              '• السباحة — ممتازة لدورة الدم\n'
              '• تمارين رفع الساق\n'
              '• دواسة القدم (foot pedal)\n\n'
              '**ممنوع:**\n'
              '• الجري على أرض صلبة\n'
              '• القفز\n'
              '• تمارين تحمل وزن عالي\n'
              '• المشي حافي (أبداً!)'
          : '🏃 **Exercise and Diabetic Foot:**\n\n'
              '**Good:**\n'
              '• Walking — 30 min daily (with proper shoes of course)\n'
              '• Seated exercises\n'
              '• Swimming — excellent for circulation\n'
              '• Leg raises\n'
              '• Foot pedal exercises\n\n'
              '**Avoid:**\n'
              '• Running on hard surfaces\n'
              '• Jumping\n'
              '• High-impact weight bearing\n'
              '• Walking barefoot (never!)';
    }

    // Smoking
    if (_matchesAny(q, ['smoke', 'دخان', 'سجائر', 'سيجارة', 'تدخين', 'cigarette', 'nicotine', 'نيكوتين'])) {
      return isRTL
          ? '🚭 **التدخين والقدم السكري:**\n\n'
              'التدخين من أسوأ العوامل اللي تزيد خطر البتر!\n\n'
              '**ليه؟**\n'
              '• النيكوتين بيضيق الأوعية الدموية\n'
              '• بيقلل تدفق الدم للقدمين\n'
              '• بيقلل الأوكسجين في الأنسجة\n'
              '• بيأخر التئام الجروح\n'
              '• بيزيد خطر الجلطات\n\n'
              '**الإقلاع عن التدخين =** تقليل خطر مضاعفات القدم بنسبة كبيرة. أهم حاجة ممكن تعملها لصحتك!'
          : '🚭 **Smoking and Diabetic Foot:**\n\n'
              'Smoking is one of the worst factors that increases amputation risk!\n\n'
              '**Why?**\n'
              '• Nicotine constricts blood vessels\n'
              '• Reduces blood flow to feet\n'
              '• Reduces oxygen in tissues\n'
              '• Delays wound healing\n'
              '• Increases clot risk\n\n'
              '**Quitting smoking =** significantly lower risk of foot complications. Best thing for your health!';
    }

    // Doctor visit / When to see doctor
    if (_matchesAny(q, ['doctor', 'دكتور', 'طبيب', 'مستشفى', 'عيادة', 'متى', 'راجع', 'روح', 'hospital', 'clinic', 'استشارة', 'زيارة'])) {
      return isRTL
          ? '🏥 **امتى تروح للدكتور فوراً:**\n\n'
              '⚠️ هذه **حالات طارئة**:\n\n'
              '• 🩹 **أي جرح** حتى لو صغير — وخصوصاً لو ما بتوجعش\n'
              '• 🔴 **احمرار أو تورم** في منطقة معينة\n'
              '• ⚫ **بقع سوداء أو زرقاء** على القدم\n'
              '• 🤒 **سخونة أو برد شديد** في قدم واحدة\n'
              '• 💨 **ريحة غير طبيعية** من جرح\n'
              '• 🔥 **حرقان شديد أو ألم مفاجئ**\n'
              '• 🦶 **تغير في شكل القدم** — ممكن Charcot foot\n'
              '• 🧊 **برودة مع تغير لون** — نقص تروية حاد\n\n'
              '📌 وفي التطبيق تقدر تعمل تقرير PDF + ترسله للدكتور على واتساب!'
          : '🏥 **When to See a Doctor Immediately:**\n\n'
              '⚠️ These are **emergencies**:\n\n'
              '• 🩹 **Any wound** even small — especially if painless\n'
              '• 🔴 **Redness or swelling** in a specific area\n'
              '• ⚫ **Black or blue spots** on the foot\n'
              '• 🤒 **Severe heat or cold** in one foot\n'
              '• 💨 **Unusual odor** from a wound\n'
              '• 🔥 **Severe burning or sudden pain**\n'
              '• 🦶 **Change in foot shape** — possible Charcot foot\n'
              '• 🧊 **Coldness with color change** — acute ischemia\n\n'
              '📌 You can also generate a PDF report + send it to your doctor via WhatsApp!';
    }

    // Charcot foot
    if (_matchesAny(q, ['charcot', 'شاركوه', 'شاركو', 'تغير شكل', 'تشوه', 'تورم مفاجئ'])) {
      return isRTL
          ? '🦶 **قدم شاركوه (Charcot Foot):**\n\n'
              'حالة خطيرة بتسبب تشوه في عظام القدم بسبب الاعتلال العصبي.\n\n'
              '**الأعراض:**\n'
              '• تورم مفاجئ في القدم (من غير ألم!)\n'
              '• احمرار\n'
              '• سخونة في القدم (الفرق >2°C عن القدم التانية)\n'
              '• تغير في شكل القدم مع الوقت\n\n'
              '**العلاج:**\n'
              '• التثبيت الفوري — ممنوع المشي\n'
              '• جبيرة أو حذاء خاص\n'
              '• متابعة دورية مع أخصائي\n\n'
              '⚠️ لو لاحظت تورم مفاجئ من غير سبب — راجع الدكتور فوراً!'
          : '🦶 **Charcot Foot:**\n\n'
              'A serious condition causing foot bone deformity due to neuropathy.\n\n'
              '**Symptoms:**\n'
              '• Sudden foot swelling (painless!)\n'
              '• Redness\n'
              '• Warm foot (difference >2°C from other foot)\n'
              '• Change in foot shape over time\n\n'
              '**Treatment:**\n'
              '• Immediate immobilization — no walking\n'
              '• Cast or special shoe\n'
              '• Regular specialist follow-up\n\n'
              '⚠️ If you notice sudden unexplained swelling — see a doctor immediately!';
    }

    // Diet / Nutrition
    if (_matchesAny(q, ['diet', 'اكل', 'أكل', 'طعام', 'غذاء', 'nutrition', 'اكل', 'رجيم', 'دايت', 'اكلات', 'طبخ', 'food', 'eat', 'meal'])) {
      return isRTL
          ? '🥗 **نصائح غذائية لصحة القدم السكري:**\n\n'
              'الغذاء الصحي بيساعد في:\n'
              '• ضبط مستوى السكر\n'
              '• تحسين الدورة الدموية\n'
              '• تقوية المناعة\n\n'
              '**مفيد:**\n'
              '• خضروات طازجة (خصوصاً الورقية)\n'
              '• بروتين قليل الدهن (سمك، دجاج مشوي)\n'
              '• حبوب كاملة (شوفان، بر)\n'
              '• دهون صحية (زيت زيتون، أفوكادو، مكسرات)\n'
              '• فيتامين B12 (مهم للأعصاب)\n'
              '• ميه كتير (8 أكواب يومياً)\n\n'
              '**قلّل:**\n'
              '• سكريات وحلويات\n'
              '• أكل مقلي وجاهز\n'
              '• ملح كتير\n'
              '• مشروبات غازية\n\n'
              '📌 استشر أخصائي تغذية عشان خطة مناسبة ليك!'
          : '🥗 **Nutrition Tips for Diabetic Foot Health:**\n\n'
              'Healthy eating helps:\n'
              '• Control blood sugar\n'
              '• Improve circulation\n'
              '• Boost immunity\n\n'
              '**Eat more:**\n'
              '• Fresh vegetables (especially leafy greens)\n'
              '• Lean protein (fish, grilled chicken)\n'
              '• Whole grains (oats, whole wheat)\n'
              '• Healthy fats (olive oil, avocado, nuts)\n'
              '• Vitamin B12 (important for nerves)\n'
              '• Water (8 glasses daily)\n\n'
              '**Reduce:**\n'
              '• Sugar and sweets\n'
              '• Fried and processed food\n'
              '• Excess salt\n'
              '• Sodas\n\n'
              '📌 Consult a nutritionist for a personalized plan!';
    }

    // Report / PDF
    if (_matchesAny(q, ['report', 'تقرير', 'pdf', 'طباعة', 'print', 'ملف', 'مستند'])) {
      return isRTL
          ? '📋 **التقارير في StepGuard:**\n\n'
              '• تقدر تعمل **تقرير PDF** لكل الفحوصات اللي عملتها\n'
              '• التقرير بيشمل: الفحص اليومي، الحرارة، اللمس، تحليل الصور\n'
              '• تقدر تضيف **رقم الدكتور** عشان ترسل له التقرير\n'
              '• وتقدر ترسله عبر **واتساب** مباشرة!\n\n'
              '📌 افتح شاشة "Report" في التطبيق وجرب!'
          : '📋 **Reports in StepGuard:**\n\n'
              '• Generate **PDF reports** for all your checkups\n'
              '• Includes: daily checkup, temperature, touch test, photo analysis\n'
              '• Add **doctor\'s number** to share the report\n'
              '• Send via **WhatsApp** directly!\n\n'
              '📌 Open the "Report" screen in the app and try it!';
    }

    // History
    if (_matchesAny(q, ['history', 'تاريخ', 'سجل', 'ساب', 'قديم', 'قبل'])) {
      return isRTL
          ? '📜 **سجل الفحوصات:**\n\n'
              '• كل الفحوصات اللي عملتها في التطبيق بتتسجل تلقائياً\n'
              '• تقدر ترجع تشوف أي فحص سابق\n'
              '• تقارن صور قديمة وجديدة\n'
              '• تقدر تحذف فحوصات قديمة\n\n'
              '📌 افتح شاشة "History" في التطبيق!'
          : '📜 **Checkup History:**\n\n'
              '• All your checkups are automatically saved\n'
              '• Review any past checkup\n'
              '• Compare old and new photos\n'
              '• Delete old checkups if needed\n\n'
              '📌 Open the "History" screen in the app!';
    }

    // Medications
    if (_matchesAny(q, ['medication', 'دواء', 'أدوية', 'علاج', 'حبوب', 'medicine', 'drug', 'prescription'])) {
      return isRTL
          ? '💊 **الأدوية والقدم السكري:\n\n'
              'الأدوية بتركز على:'
              '• **ضبط السكر** — أنسولين أو أدوية فموية'
              '• **الدورة الدموية** — أدوية لتوسيع الأوعية'
              '• **الألم العصبي** — جابابنتين، بريجابالين، أميتريبتيلين'
              '• **مضادات تخثر** — أسبرين، بلافيكس (لو في PAD)'
              '• **مضادات حيوية** — لو في عدوى'
              '• **العناية بالجروح** — مراهم وكريمات متخصصة'
              '⚠️ مهم: ما تاخدش أي دواء غير باستشارة الدكتور!'
          : '💊 **Medications and Diabetic Foot:\n\n'
              'Medications focus on:'
              '• **Blood sugar control** — insulin or oral medications'
              '• **Circulation** — vasodilators'
              '• **Neuropathic pain** — gabapentin, pregabalin, amitriptyline'
              '• **Anticoagulants** — aspirin, plavix (for PAD)'
              '• **Antibiotics** — if infection is present'
              '• **Wound care** — specialized ointments and dressings'
              '⚠️ Important: Don\'t take any medication without consulting your doctor!';
    }

    // Amputation / Surgery
    if (_matchesAny(q, ['amputation', 'بتر', 'قطع', 'جراحة', 'سurger', 'عملية', 'تجر'])) {
      return isRTL
          ? '⚠️ **بتر الأطراف ومرضى السكري:**\n\n'
              'احصائيات صادمة:\n'
              '• كل **20 ثانية**، بيتم بتر طرف في مكان في العالم\n'
              '• **85%** من حالات البتر سببها قرحة القدم\n'
              '• **50-70%** نسبة الوفيات خلال 5 سنين بعد البتر\n'
              '• البتر ممكن يكون بإصبع، جزء من القدم، أو فوق الكاحل\n\n'
              '**الخبر الجيد:**\n'
              '• **45-85%** من حالات البتر يمكن **منعها** بالكشف المبكر والرعاية المنتظمة'
              '• StepGuard صمم عشان يساعدك تعتني بقدمك وتمنع المضاعفات قبل ما توصل لكده'
              '📌 استخدم التطبيق يومياً — الفحص البسيط ممكن ينقذ رجلك!'
          : '⚠️ **Amputation in Diabetic Patients:**\n\n'
              'Shocking statistics:'
              '• Every **20 seconds**, a limb is amputated somewhere in the world'
              '• **85%** of amputations are preceded by a foot ulcer'
              '• **50-70%** 5-year mortality rate after amputation'
              '• Amputation can be of a toe, part of the foot, or above the ankle\n\n'
              '**The good news:**'
              '• **45-85%** of amputations are **preventable** with early detection and regular care'
              '• StepGuard is designed to help you care for your feet and prevent complications before they reach this point'
              '📌 Use the app daily — a simple checkup can save your foot!';
    }

    // General greeting / thanks
    if (_matchesAny(q, ['شكر', 'thanks', 'thank', 'merci', 'تمام', 'ok', 'good', 'nice', 'كفو', 'يعطيك', 'بارك'])) {
      return isRTL
          ? 'العفو! 🫡 أنا موجود عشان أساعدك. لو عندك أي سؤال تاني عن القدم السكري أو التطبيق، أنا تحت أمرك.'
          : 'You\'re welcome! 🫡 I\'m here to help. If you have any other questions about diabetic foot care or the app, I\'m at your service.';
    }

    // Default / Unknown
    return isRTL
        ? '🤔 سؤالك محتاج خبرة أوسع من اللي عندي محلياً.\n\n'
            'التطبيق بيستخدم Gemini AI من Google عشان يجاوب على الأسئلة المعقدة، بس الحصة الشهرية خلصت.\n\n'
            '**جرب تسأل حاجة من دول:**\n'
            '• "إحصائيات القدم السكري"\n'
            '• "نصائح للوقاية"\n'
            '• "عوامل الخطورة"\n'
            '• "امتى أروح للدكتور"\n'
            '• "إيه هو StepGuard"\n'
            '• "العناية بالجروح"\n'
            '• "تصنيف IWGDF"\n\n'
            'أو جدد API key من https://aistudio.google.com/apikey عشان ترجع تستخدم Gemini.'
        : '🤔 Your question needs more expertise than my local knowledge base.\n\n'
            'The app uses Google\'s Gemini AI for complex questions, but the free monthly quota ran out.\n\n'
            '**Try asking one of these:**\n'
            '• "Diabetic foot statistics"\n'
            '• "Prevention tips"\n'
            '• "Risk factors"\n'
            '• "When to see a doctor"\n'
            '• "What is StepGuard"\n'
            '• "Wound care"\n'
            '• "IWGDF classification"\n\n'
            'Or get a new API key at https://aistudio.google.com/apikey to use Gemini again.';
  }

  static bool _matchesAny(String query, List<String> keywords) {
    for (final kw in keywords) {
      if (query.contains(kw)) return true;
    }
    return false;
  }
}
