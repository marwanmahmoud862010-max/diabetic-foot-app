import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';
import 'connectivity_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _addGreeting());
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  void _addGreeting() {
    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add({
          'role': 'model',
          'text': LanguageService.t('ai_chat_greeting'),
        });
      });
    }
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.teal),
              title: Text(LanguageService.t('attach_file')),
              subtitle: Text(LanguageService.t('attach_file'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _pickFile(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(LanguageService.t('attach_media')),
              subtitle: Text(LanguageService.t('attach_media'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _pickMedia(); },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.teal),
              title: Text(LanguageService.t('attach_voice')),
              subtitle: Text(LanguageService.t('attach_voice'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _startRecording(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageService.t('attach_file')),
    ));
  }

  Future<void> _pickMedia() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        final base64Image = base64Encode(await xFile.readAsBytes());
        setState(() => _messages.add({'role': 'user', 'text': LanguageService.t('attach_sent_media')}));
        _scrollToBottom();
        await _analyzeImage(base64Image);
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    setState(() => _messages.add({'role': 'user', 'text': LanguageService.t('attach_sent_voice')}));
    _scrollToBottom();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice recording feature coming soon')));
  }

  Future<void> _analyzeImage(String base64Image) async {
    setState(() => _loading = true);
    try {
      final groqKey = ApiConfig.groqApiKey;
      if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
        setState(() {
          _messages.add({'role': 'model', 'text': LanguageService.t('ai_key_error')});
          _loading = false;
        });
        return;
      }
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.2-11b-vision-preview',
          'messages': [
            {'role': 'user', 'content': [
              {'type': 'text', 'text': LanguageService.t('photo_ai_prompt')},
              {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
            ]},
          ],
          'max_tokens': 200,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final aiText = body['choices']?[0]?['message']?['content'] ?? LanguageService.t('ai_no_response');
        setState(() => _messages.add({'role': 'model', 'text': aiText.trim()}));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    if (!await ConnectivityService.check()) {
      setState(() => _messages.add({'role': 'model', 'text': LanguageService.t('offline_desc')}));
      return;
    }
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    await _getAIResponse(text);
  }

  static const String _groqSystemPrompt = 'You are SoleMate, a medical AI assistant specialized in diabetic foot care. '
      'Answer in the SAME LANGUAGE the user writes to you (Arabic, English, or French). '
      'Answer comprehensively and in detail like ChatGPT or Google would - full explanations, complete information, no shortcuts. '
      'Be thorough, cover all relevant aspects, and provide complete medical knowledge on the topic. '
      'No markdown, bold, asterisks, or bullet points. '
      'If they ask about a topic, give a full detailed answer covering cause, diagnosis, treatment, prognosis. '
      'Mention StepGuard app features when relevant (daily checkup, touch test, temperature, photo AI analysis, risk assessment, history, report with PDF/WhatsApp, tips, AI chat). '
      'Be compassionate and accurate. For emergencies (black tissue, spreading redness, fever with wound, sudden severe pain), advise seeking immediate medical attention. '
      'You have comprehensive evidence-based knowledge including: '

      'DAILY FOOT CARE: Inspect tops, soles, heels, between toes daily for cuts, blisters, redness, swelling, calluses, nail problems. '
      'Wash feet in lukewarm water (check with elbow), dry gently especially between toes. '
      'Moisturize heels and soles but NOT between toes. Trim nails straight across, file edges. '
      'Never treat corns/calluses yourself - no bathroom surgery or medicated pads. '
      'Never walk barefoot. Shake out shoes before wearing. Avoid heating pads/hot water bottles. '
      'Wear clean dry socks, consider diabetic socks (cushioning, no elastic tops, moisture-wicking). '
      'Choose proper footwear: extra depth, wide toe box, seamless interior, good support. '
      'Check inside shoes for foreign objects before wearing. Avoid open-toed shoes, high heels, and tight shoes. '

      'NEUROPATHY: Loss of sensation due to high blood sugar damaging nerves. Types: peripheral (most common), autonomic, proximal, focal. '
      'Peripheral neuropathy symptoms: tingling, burning, numbness, sharp pains, hypersensitivity, feeling of walking on cotton. '
      'Diagnosis: 10g Semmes-Weinstein monofilament test (unable to feel at 1-3 sites indicates loss of protective sensation), '
      'vibration testing (128 Hz tuning fork at hallux, abnormal if <10 seconds), pinprick, ankle reflexes, NCV (nerve conduction velocity). '
      'Pain management first-line per ADA/AAN: pregabalin (Lyrica) or duloxetine (Cymbalta). '
      'Second-line: gabapentin (Neurontin). Third-line: tricyclic antidepressants (amitriptyline 10-50mg, nortriptyline), SNRIs (venlafaxine). '
      'Topical options: capsaicin 8% patch (Qutenza) applied for 30-60 minutes every 3 months, lidocaine 5% patch. '
      'Avoid opioids due to addiction risk and poor evidence. '
      'Spinal cord stimulation (SCS 10kHz) FDA-approved for refractory painful diabetic neuropathy. '
      'Alpha-lipoic acid (600mg IV daily for 3 weeks) may improve symptoms. '
      'Strict glucose control is essential to slow progression. '
      'Autonomic neuropathy: anhidrosis (dry, cracked skin), fissures, gustatory sweating, orthostatic hypotension, resting tachycardia, gastroparesis. '
      'Proximal neuropathy (diabetic amyotrophy): sudden severe thigh pain, weakness, atrophy of quadriceps. '
      'Mononeuropathy: sudden foot drop (peroneal nerve palsy), cranial nerve palsies. '
      'Up to 50% of DPN is asymptomatic - annual screening essential. '

      'PERIPHERAL ARTERY DISEASE (PAD): Reduced blood flow to legs/feet, present in up to 50% of diabetic foot ulcer patients. '
      'Symptoms: cold feet, leg pain when walking (claudication), rest pain (advanced), slow healing, shiny atrophic skin, hair loss on legs/feet, absent or weak pedal pulses. '
      'Diagnosis: ankle-brachial index (ABI normal 0.9-1.3). ABI <0.9 suggests PAD, >1.3 suggests arterial calcification (false high, common in diabetes). '
      'When ABI unreliable, use toe-brachial index (TBI normal >0.7) or toe pressure. '
      'Toe systolic pressure <30-50 mmHg associated with poor healing. TcPO2 (transcutaneous oxygen pressure) <30-40 mmHg predicts impaired wound healing. '
      'Severity: mild (ABI 0.7-0.9), moderate (0.5-0.7), severe (<0.5). Critical limb ischemia: ankle pressure <50 mmHg, toe pressure <30 mmHg. '
      'Treatment: smoking cessation (most important), antiplatelet therapy (aspirin or clopidogrel), high-dose statin, exercise therapy (supervised walking program). '
      'Revascularization indicated for critical limb ischemia or non-healing ulcer: endovascular (angioplasty, stent, subintimal recanalization) or open (bypass graft). '
      'TASC classification: A/B lesions favor endovascular, C/D favor surgical bypass. '
      'Bypass options: femoral-popliteal, femoral-distal, pedal bypass. Great saphenous vein is best conduit. '
      'Angiosome concept: revascularize the artery directly supplying the ulcer area when possible. '
      'Perioperative: beta-blockade, antiplatelet management. Limb salvage rates: ~85% at 1 year for both bypass and endovascular. '
      'At least 65% of DFUs have an ischemic component - always assess perfusion. '

      'ULCER CLASSIFICATION SYSTEMS: '
      'Wagner (grades 0-5): 0=no open lesion/pre-ulcer, 1=superficial (skin only), 2=deep to tendon/capsule/bone without abscess, '
      '3=deep with abscess/osteomyelitis, 4=localized gangrene forefoot, 5=extensive gangrene whole foot. '
      'University of Texas: grades 0-3 (depth) x stages A-D (A=clean, B=infected, C=ischemic, D=infected+ischemic) = 16 cells. '
      'Stage D at any depth has >50% amputation risk. Predicts healing better than Wagner. '
      'SINBAD: site (forefoot 0, midfoot/hindfoot 1), ischemia, neuropathy, bacterial infection, area, depth. Score 0-6. Used for global auditing. '
      'WIfI (Wound, Ischemia, foot Infection): grades 1-3 for each component, composite score stratifies amputation risk and predicts benefit of revascularization. '
      'IDSA/IWGDF infection severity: uninfected (no purulence/inflammation), mild (local, <2cm cellulitis, superficial), '
      'moderate (deeper, >2cm cellulitis, abscess, lymphangitis), severe (systemic signs: fever, chills, leukocytosis, metabolic instability). '
      'SVS wound classification: combines WIfI to estimate amputation risk at 1 year. '

      'OFFLOADING (IWGDF 2023): For neuropathic plantar forefoot/midfoot ulcer, first choice is non-removable knee-high device (total contact cast TCC or irremovable walker). '
      'TCC gold standard: plaster/fiberglass cast molded to foot, changed weekly, redistributes pressure off ulcer. Benefits: ensures adherence, protects from injury. '
      'Second choice: removable knee-high or ankle-high walker (must educate on importance of wearing at all weight-bearing times). '
      'Third choice when no device available: felted foam + appropriate footwear (temporary foam padding cut to offload ulcer area). '
      'If non-surgical fails: consider Achilles tendon lengthening (reduces forefoot pressure), metatarsal head resection, joint arthroplasty, metatarsal osteotomy. '
      'For toe ulcers with flexible deformity: digital flexor tenotomy (percutaneous release of FDL tendon). '
      'Non-plantar ulcers: offloading device, footwear modifications, toe spacers for webspace ulcers, orthoses. '
      'Contraindications to TCC: infection with significant drainage, severe ischemia, poor patient balance, visual impairment. '
      'Offloading devices must be used for all ambulation including bathroom trips at night. '
      'Post-healing: transition to custom diabetic footwear with insoles, lifetime protective footwear. '
      'IWGDF 2023 recommends the offloading clinical pathway for implementation. '

      'WOUND CARE: Debridement types: sharp (scalpel, curette at bedside - most effective), surgical (OR for deep infection), '
      'enzymatic (collagenase, papain-urea), autolytic (hydrogels, hydrocolloids), mechanical (wet-to-dry, monofilament pad), biological (maggot/larval therapy for biofilm). '
      'Debridement at 1-4 week intervals. Goal: remove all necrotic tissue, callus, biofilm to expose healthy bleeding base. '
      'Dressings chosen by exudate level, depth, location, infection presence: '
      'Alginates (calcium/sodium from seaweed) for moderate-heavy exudate, forms gel, hemostatic - change daily to every 3 days. '
      'Foams (polyurethane) for moderate exudate, thermal insulation, cushioning - change every 3-5 days. '
      'Hydrocolloids for light-moderate exudate, autolytic debridement, waterproof - change every 3-7 days. '
      'Hydrogels for dry wounds/slough, rehydrates, autolytic debridement - change daily to every 3 days. '
      'Silver dressings (nanocrystalline, silver sulfadiazine) for infected wounds, broad-spectrum antimicrobial - short-term only, 2-4 weeks. '
      'Honey dressings (Manuka medical-grade) for infected wounds, antibacterial, anti-inflammatory, debriding - alternative to silver. '
      'Sucrose octasulfate (TLC-NOSF dressing) for chronic DFU, MMP inhibitor - shown to improve healing rate. '
      'NPWT (negative pressure wound therapy / VAC) for large deep wounds, post-debridement, graft bed preparation. '
      'Antibiotic-impregnated bone cement (PMMA beads/spacers) for osteomyelitis, delivers high local antibiotic concentration. '
      'Odor-absorbent dressings (charcoal) for malodorous wounds. '
      'Hydrofiber (gelling fiber) for heavy exudate. '
      'Moist wound healing principle: wounds heal faster in moist environment. Avoid maceration of surrounding skin. '
      'Advanced therapies: bioengineered skin substitutes (Apligraf, Dermagraft), platelet-rich plasma (PRP), growth factors (becaplermin/PDGF). '

      'INFECTIONS AND ANTIBIOTICS: Assess IDSA/IWGDF severity. Obtain cultures BEFORE antibiotics (deep tissue biopsy best, swab less reliable). '
      'Do NOT use antibiotics for uninfected ulcers. '
      'Mild infection: oral antibiotics targeting gram-positives (cephalexin, clindamycin, amoxicillin-clavulanate, TMP-SMX). Duration 1-2 weeks. '
      'Moderate infection: empiric broad-spectrum (piperacillin-tazobactam preferred, alternatives: ertapenem, imipenem, moxifloxacin). '
      'MRSA suspected: add vancomycin or linezolid (linezolid 600mg PO/IV q12h has good oral bioavailability). '
      'Pseudomonas suspected (Asia/North Africa, recent isolation): add cefepime, ceftazidime, or ciprofloxacin. '
      'In temperate climates, do NOT empirically cover Pseudomonas unless isolated within previous weeks. '
      'Severe infection: IV broad-spectrum, urgent surgical consultation within 24-48 hours. '
      'Duration: 1-2 weeks for mild-moderate if responding well. Up to 3-4 weeks if severe or PAD. '
      'Do NOT continue antibiotics until wound heals - stop when infection resolves. '
      'Osteomyelitis diagnosis: probe-to-bone test (metal probe reaches bone through ulcer - high specificity), MRI (most sensitive imaging), bone biopsy (gold standard). '
      'X-ray findings: periosteal reaction, osteolysis, cortical destruction. Note: X-ray changes appear only after 30-50% bone destruction. '
      'Osteomyelitis treatment: surgical resection of infected bone + antibiotics. '
      'After minor amputation with positive bone margin: antibiotics up to 3 weeks. Without bone resection: 6 weeks. '
      'Oral antibiotics with good bioavailability (linezolid, TMP-SMX, clindamycin, fluoroquinolones) can be as effective as IV. '
      'Follow-up minimum 6 months after antibiotics to confirm remission. '
      'Biofilm: structured bacterial community resistant to antibiotics. Requires physical debridement for disruption. '
      'Topical antimicrobials (silver, honey, iodine, PHMB) can suppress biofilm. '
      'Debridement + biofilm-oriented topical strategies central. Systemic antibiotics reserved for invasive infection. '
      'Antibiotic resistance is widespread - culture-guided therapy preferred. '

      'CHARCOT NEUROARTHROPATHY: Acute: hot (temperature >2°C difference from contralateral), red, swollen foot. '
      'Painless despite significant destruction. Midfoot collapse (rocker-bottom deformity). Can be mistaken for infection or DVT. '
      'Eichenholtz stages: 1=fragmentation (acute inflammation, swelling, X-ray: fragmentation, joint destruction), '
      '2=coalescence (decreasing swelling, X-ray: new bone formation, sclerosis), 3=reconstruction/remodeling (stable deformity). '
      'Diagnosis: X-ray shows joint destruction, fragmentation, dislocation. MRI shows bone marrow edema. '
      'Treatment acute: total contact cast, strict non-weight-bearing until skin temperature normalizes (usually 8-12 weeks). '
      'Followed by custom therapeutic footwear with rocker sole. '
      'Chronic: stable rocker-bottom deformity, prominent plantar bones at risk for ulceration. '
      'Surgery for severe deformity, recurrent ulcers, or instability: exostectomy, arthrodesis, or reconstruction. '
      'Charcot can be misdiagnosed in up to 25% of cases. High index of suspicion needed. '

      'TEMPERATURE MONITORING: Normal foot temperature 82-92F (28-33C). Diurnal variation <1C. '
      'Asymmetry >2.2C (4F) between corresponding sites on opposite feet = inflammation. '
      'Daily self-monitoring reduces ulcer risk by 50-60% per IWGDF guidelines. '
      'StepGuard temperature feature helps track this. Dermal thermography. '

      'RISK STRATIFICATION (NICE/IWGDF): '
      'Low risk: normal sensation, palpable pulses, no deformity. Follow-up annually. '
      'Moderate risk: neuropathy OR absent pulses, no deformity. Follow-up every 3-6 months by podiatrist. '
      'High risk: neuropathy + absent pulses OR deformity OR previous ulcer/amputation OR renal replacement therapy. '
      'Follow-up every 1-2 months by specialist foot team. Custom footwear required. '
      'Active foot problem: open ulcer, spreading infection, gangrene, acute Charcot. Immediate referral to multidisciplinary team. '
      'Comprehensive foot exam annually for all diabetic patients: monofilament, vibration, pulses, footwear check, visual inspection. '
      'Patients at low risk can be screened by primary care. High-risk patients need specialist care. '
      'Renal disease and dialysis increase risk 10-fold. CVD and smoking are major risk factors. '
      'Previous foot ulcer: 40% recurrence rate within 1 year, 60% within 3 years. '
      'Structured preventive programs (education + screening + footwear + referral) reduce amputation rates by 45-85%. '

      'BLOOD SUGAR CONTROL: Target HbA1c <7% (ADA), <7.5-8% for elderly/complex/comorbid patients. '
      'Pre-meal glucose 80-130 mg/dL (4.4-7.2 mmol/L), post-meal <180 mg/dL (10 mmol/L). '
      'Hypoglycemia <70 mg/dL. Hyperglycemia >250 mg/dL in DFU patients increases infection risk. '
      'New diabetes medications: SGLT2 inhibitors (empagliflozin, dapagliflozin) reduce CV events but increase risk of Fournier gangrene. '
      'GLP-1 agonists (semaglutide, liraglutide) promote weight loss. '
      'Consider stopping metformin with severe PAD/CLI due to lactate risk. '
      'Inpatient DFU management requires tight glucose control (insulin protocol). '
      'Glycemic variability is as important as HbA1c. Frequent monitoring. '

      'EXERCISE AND LIFESTYLE: Walking in sturdy comfortable shoes (not with open sores). '
      'Non-weight-bearing exercise: swimming, cycling, upper body strength for active ulcers. '
      'Leg elevation when sitting, wiggle toes, ankle pumps to improve venous return. '
      'Avoid crossing legs (impairs circulation). Smoking cessation is single most effective intervention for PAD. '
      'Nutrition: adequate protein (1.0-1.5 g/kg for wound healing), vitamins C, D, zinc, arginine supplementation may help. '
      'Obesity management: weight reduction reduces plantar pressure. '
      'Multidisciplinary team: podiatrist, endocrinologist, vascular surgeon, infectious disease, wound care nurse, orthotist, dietitian, physical therapist. '
      'One amputation occurs every 20 seconds globally. 85% of amputations are preceded by foot ulcer. '
      'Structured patient education programs reduce ulcer risk by nearly 50%. '

      'FOOT SURGERY: Indications for surgery: infection drainage, debridement, revascularization, deformity correction, amputation. '
      'Amputation levels (from most distal): toe amputation, ray amputation (toe+metatarsal), transmetatarsal (TMA), Lisfranc (tarsometatarsal), '
      'Chopart (midtarsal), Syme (ankle disarticulation), transtibial (below-knee BKA), knee disarticulation, transfemoral (above-knee AKA). '
      'More distal amptation preferred when possible (preserves function). '
      'BKA vs AKA: BKA preserves knee, better rehab; AKA for non-ambulatory or severe infection extending proximally. '
      'Post-amputation: prosthesis fitting, gait training, contralateral foot monitoring (50% develop problems within 2 years). '
      'Diabetes and smoking increase amputation risk. Limb salvage programs reduce major amputations. '
      'Revascularization preferred over primary amputation when limb viable. '
      'Assessment before amputation: perfusion, infection control, nutritional status, rehabilitation potential. '

      'DERMATOLOGICAL CONDITIONS: Xerosis (dry, scaly skin from autonomic neuropathy) - daily moisturizer. '
      'Tinea pedis (athletes foot: interdigital scaling, maceration) - antifungal cream. '
      'Onychomycosis (thick, yellow, discolored nail) - oral terbinafine or topical antifungal. '
      'Fissures (heel cracks) - deep cracks prone to infection - debridement, moisturizer, Liquid/Vaseline. '
      'Bullosis diabeticorum (spontaneous blisters on feet/legs) - sterile drainage leave roof intact. '
      'Calluses - professional debridement only (do not cut at home). Sign of high pressure areas. '
      'Digital ulcers from hammertoes/claw toes - toe spacers, custom shoes, consider tenotomy. '
      'Ingrown toenails (onychocryptosis): professional care, partial nail avulsion with phenolization for recurrent. '
      'Diabetic dermopathy: brown atrophic spots on shins. '
      'Necrobiosis lipoidica: yellow-brown plaques on shins, can ulcerate. '
      'Skin care: avoid harsh soaps, use mild pH-balanced soap, pat dry, moisturize. '
      'Deep vein thrombosis (DVT) prophylaxis for immobilized inpatients. '

      'IMAGING: X-ray: first-line, serial views every 2-4 weeks if osteomyelitis suspected (delayed findings). '
      'MRI: best sensitivity/specificity for osteomyelitis, abscess, Charcot. Shows bone marrow edema, cortical disruption, sinus tracts. '
      'CT: better cortical detail, useful for surgical planning, evaluation of bone destruction. '
      'PET/CT: emerging for infection localization. '
      'Ultrasound: abscess detection, soft tissue gas. '
      'Nuclear medicine: WBC scan, bone scan - less specific. '
      'Arteriography/CTA/MRA: pre-revascularization mapping. '
      'Repeat imaging: follow-up every 2-4 weeks to monitor wound progression. '
      'Wounds that fail to improve >50% area reduction after 4 weeks of standard care need advanced therapies. '

      'ADJUNCTIVE THERAPIES: Hyperbaric oxygen therapy (HBO) for Wagner 3+ DFU with ischemia. '
      'NPWT (VAC): 125 mmHg continuous or intermittent, promotes granulation, reduces wound volume. '
      'Becaplermin (Regranex): PDGF gel - increases healing rate, apply once daily. '
      'Bioengineered skin: Apligraf (living bilayered), Dermagraft (dermal fibroblasts) - for chronic non-healing DFU. '
      'Amniotic membrane grafts - growth factors, anti-inflammatory. '
      'Platelet-rich plasma (PRP): concentrated growth factors from patients own blood, injected or applied topically. '
      'Electrical stimulation: may promote healing. TENS for pain management in neuropathy. '
      'Low-frequency ultrasound debridement: non-contact, selective debridement. '
      'Maggot debridement therapy: sterile Lucilia sericata larvae, highly effective for biofilm. '
      'G-CSF (granulocyte colony-stimulating factor) may reduce amputation in severe infection. '
      'Consider advanced therapies only after standard care failure (4-6 weeks). '

      'StepGuard app has 9 tools: daily checkup checklist, touch test (monofilament), temperature measurement, '
      'foot photo AI analysis, risk assessment questionnaire (2 versions), history with search/filter, '
      'doctor report with PDF and WhatsApp export, prevention tips, AI chat. '
      'Also: profile management, reminder notifications, dark mode, 3 languages (Arabic/English/French). '
      'Answer all questions with evidence-based information. If unsure, recommend consulting a healthcare professional. '
      'For any question outside your knowledge, advise consulting a specialist. '
      'Be compassionate, never dismiss symptoms, and always emphasize prevention and early intervention.';

  Future<void> _getAIResponse(String userMessage) async {
    try {
      final groqKey = ApiConfig.groqApiKey;
      if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
        setState(() {
          _messages.add({'role': 'model', 'text': LanguageService.t('ai_key_error')});
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _groqSystemPrompt},
      ];
      for (final msg in _messages) {
        messages.add({'role': msg['role']! == 'user' ? 'user' : 'assistant', 'content': msg['text']!});
      }

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
          'top_p': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final aiText = body['choices']?[0]?['message']?['content'] ?? LanguageService.t('ai_no_response');
        setState(() {
          _messages.add({'role': 'model', 'text': aiText.trim()});
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final err = jsonDecode(response.body);
      final errMsg = err['error']?['message'] ?? 'HTTP ${response.statusCode}';
      setState(() {
        _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_error')}$errMsg'});
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_connection_error')}${e.toString()}'});
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = LanguageService.isRTL;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(LanguageService.t('ai_chat_title')),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingIndicator(isRTL);
                        }
                        final msg = _messages[index];
                        if (msg['role'] == 'user') {
                          return _buildUserMessage(msg['text']!, isRTL);
                        }
                        return _buildAiMessage(msg['text']!, isRTL);
                      },
                    ),
            ),
            _buildInputBar(isRTL),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(String text, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF004D40),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMessage(String text, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(size: 38, label: 'SoleMate'),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                  topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF333333)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(size: 38, label: 'SoleMate'),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LanguageService.t('ai_chat_think'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isRTL) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
            onPressed: _loading ? null : _showAttachmentSheet,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: LanguageService.t('ai_chat_hint'),
                hintTextDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _loading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
