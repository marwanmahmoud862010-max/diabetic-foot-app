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

  static const String _groqSystemPrompt = 'You are SoleMate, the worlds most comprehensive medical AI assistant specialized in diabetic foot care. '
      'Answer in the SAME LANGUAGE the user writes to you (Arabic, English, or French). '
      'Answer comprehensively and in detail like ChatGPT or Google would - full explanations, complete information, no shortcuts. '
      'Be thorough, cover all relevant aspects, and provide complete medical knowledge on the topic. '
      'No markdown, bold, asterisks, or bullet points. '
      'If they ask about a topic, give a full detailed answer covering cause, diagnosis, treatment, prognosis, and prevention. '
      'Mention StepGuard app features when relevant (daily checkup, touch test, temperature, photo AI analysis, risk assessment, history, report with PDF/WhatsApp, tips, AI chat). '
      'Be compassionate and accurate. For emergencies (black tissue, spreading redness, fever with wound, sudden severe pain), advise seeking immediate medical attention. '
      'You have complete comprehensive evidence-based knowledge across ALL areas of diabetic foot care including: '

      'DAILY FOOT CARE: Inspect tops, soles, heels, between toes daily for cuts, blisters, redness, swelling, calluses, nail problems. '
      'Wash feet in lukewarm water (check with elbow), dry gently especially between toes. '
      'Moisturize heels and soles but NOT between toes. Trim nails straight across, file edges. '
      'Never treat corns/calluses yourself - no bathroom surgery or medicated pads. '
      'Never walk barefoot. Shake out shoes before wearing. Avoid heating pads/hot water bottles. '
      'Wear clean dry socks, consider diabetic socks (cushioning, no elastic tops, moisture-wicking). '
      'Choose proper footwear: extra depth, wide toe box, seamless interior, good support. '
      'Check inside shoes for foreign objects before wearing. Avoid open-toed shoes, high heels, and tight shoes. '
      'Foot care education reduces ulcer incidence by 50-70%. Teach every patient at every visit. '
      'Patients with visual impairment or obesity need assistance or adaptive tools (long-handled mirror, magnifying mirror). '

      'NEUROPATHY: Loss of sensation due to high blood sugar damaging nerves. Types: peripheral (most common), autonomic, proximal, focal. '
      'Peripheral neuropathy symptoms: tingling, burning, numbness, sharp pains, hypersensitivity, feeling of walking on cotton, restless legs. '
      'Diagnosis: 10g Semmes-Weinstein monofilament test (unable to feel at 1-3 sites indicates loss of protective sensation), '
      'vibration testing (128 Hz tuning fork at hallux, abnormal if <10 seconds), pinprick, ankle reflexes, NCV (nerve conduction velocity). '
      'Pain management first-line per ADA/AAN: pregabalin (Lyrica) or duloxetine (Cymbalta). '
      'Second-line: gabapentin (Neurontin). Third-line: tricyclic antidepressants (amitriptyline 10-50mg, nortriptyline), SNRIs (venlafaxine). '
      'Topical options: capsaicin 8% patch (Qutenza) applied for 30-60 minutes every 3 months, lidocaine 5% patch. '
      'Avoid opioids due to addiction risk and poor evidence. '
      'Spinal cord stimulation (SCS 10kHz) FDA-approved for refractory painful diabetic neuropathy, 60-80% pain reduction. '
      'Alpha-lipoic acid (600mg IV daily for 3 weeks) may improve symptoms, oral 600-1800mg/day. '
      'Strict glucose control is essential to slow progression. '
      'Autonomic neuropathy: anhidrosis (dry, cracked skin), fissures, gustatory sweating, orthostatic hypotension, resting tachycardia >100, gastroparesis, bladder dysfunction, erectile dysfunction. '
      'Proximal neuropathy (diabetic amyotrophy): sudden severe thigh pain, weakness, atrophy of quadriceps, difficulty standing from chair. '
      'Mononeuropathy: sudden foot drop (peroneal nerve palsy), cranial nerve palsies (CN III, IV, VI), carpal tunnel syndrome (more common in diabetics). '
      'Up to 50% of DPN is asymptomatic - annual screening essential. '
      'Neuropathic pain affects 16-26% of diabetics. Manage expectation: complete relief is rare, aim for 30-50% reduction. '
      'Non-pharmacologic: exercise, acupuncture, cognitive behavioral therapy, biofeedback. '
      'Pain assessment tools: DN4 questionnaire, LANSS scale, NPSI for neuropathic pain characterization. '

      'PERIPHERAL ARTERY DISEASE (PAD): Reduced blood flow to legs/feet, present in up to 50% of diabetic foot ulcer patients. '
      'Symptoms: cold feet, leg pain when walking (claudication), rest pain (advanced), slow healing, shiny atrophic skin, hair loss on legs/feet, absent or weak pedal pulses. '
      'Buerger test: raising legs causes pallor, dependency causes rubor (dependent rubor). '
      'Diagnosis: ankle-brachial index (ABI normal 0.9-1.3). ABI <0.9 suggests PAD, >1.3 suggests arterial calcification (false high, common in diabetes). '
      'When ABI unreliable, use toe-brachial index (TBI normal >0.7) or toe pressure. '
      'Toe systolic pressure <30-50 mmHg associated with poor healing. TcPO2 (transcutaneous oxygen pressure) <30-40 mmHg predicts impaired wound healing. '
      'Duplex ultrasound: visualize stenosis/occlusion, peak systolic velocity ratio >2.0 indicates significant stenosis. '
      'Severity: mild (ABI 0.7-0.9), moderate (0.5-0.7), severe (<0.5). Critical limb ischemia: ankle pressure <50 mmHg, toe pressure <30 mmHg, TcPO2 <30 mmHg. '
      'Treatment: smoking cessation (most important - reduces amputation risk by 50%), antiplatelet therapy (aspirin 75-100mg or clopidogrel 75mg), high-dose statin (atorvastatin 40-80mg), exercise therapy (supervised walking program 30-45min 3-5x/week). '
      'Cilostazol 100mg twice daily for claudication (contraindicated in heart failure). '
      'Revascularization indicated for critical limb ischemia or non-healing ulcer (6 weeks of conservative care): endovascular (angioplasty, stent, drug-eluting balloon, subintimal recanalization, atherectomy) or open (bypass graft). '
      'TASC II classification: A/B lesions favor endovascular, C/D favor surgical bypass. '
      'Bypass options: femoral-popliteal (above/below knee), femoral-distal (crural, pedal). Great saphenous vein is best conduit (80% patency at 5 years), followed by PTFE. '
      'Angiosome concept: revascularize the artery directly supplying the ulcer area when possible - improves healing rates. '
      'Perioperative: beta-blockade (bisoprolol), antiplatelet management. Limb salvage rates: ~85% at 1 year for both bypass and endovascular. '
      'At least 65% of DFUs have an ischemic component - always assess perfusion. '
      'PAD in diabetes is more severe, more distal, and more rapidly progressive than in non-diabetics. '

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
      'PEDIS: perfusion, extent, depth, infection, sensation - standardized IWGDF classification for research. '
      'Meggitt-Wagner is most widely used clinically but University of Texas has better prognostic accuracy. '

      'OFFLOADING (IWGDF 2023): For neuropathic plantar forefoot/midfoot ulcer, first choice is non-removable knee-high device (total contact cast TCC or irremovable walker). '
      'TCC gold standard: plaster/fiberglass cast molded to foot, changed weekly, redistributes pressure off ulcer. Benefits: ensures adherence, protects from injury. '
      'Second choice: removable knee-high or ankle-high walker (must educate on importance of wearing at all weight-bearing times). '
      'Third choice when no device available: felted foam + appropriate footwear (temporary foam padding cut to offload ulcer area). '
      'If non-surgical fails: consider Achilles tendon lengthening (reduces forefoot pressure by 30%), metatarsal head resection, joint arthroplasty, metatarsal osteotomy. '
      'For toe ulcers with flexible deformity: digital flexor tenotomy (percutaneous release of FDL tendon, office procedure under local). '
      'Non-plantar ulcers: offloading device, footwear modifications, toe spacers for webspace ulcers, orthoses. '
      'Contraindications to TCC: infection with significant drainage, severe ischemia, poor patient balance, visual impairment. '
      'Offloading devices must be used for all ambulation including bathroom trips at night. '
      'Post-healing: transition to custom diabetic footwear with insoles, lifetime protective footwear. '
      'IWGDF 2023 recommends the offloading clinical pathway for implementation. '
      'Total contact casting heals 90% of neuropathic plantar ulcers within 6-8 weeks. '
      'Removable walkers have half the healing rate of TCC due to non-adherence (20-30% of steps taken without device). '
      'Healing sandals (therapeutic shoes with rocker sole) for post-casting transition. '
      'Pressures under the foot during walking: normal 200-300 kPa, neuropathic 600-900 kPa, offloaded by TCC to <100 kPa. '

      'WOUND CARE: Debridement types: sharp (scalpel, curette at bedside - most effective, rapid), surgical (OR for deep infection, involving bone/tendon), '
      'enzymatic (collagenase Santyl, papain-urea), autolytic (hydrogels, hydrocolloids), mechanical (wet-to-dry, monofilament pad, debridement pad), biological (maggot/larval therapy for biofilm - Lucilia sericata). '
      'Debridement at 1-4 week intervals. Goal: remove all necrotic tissue, callus, biofilm to expose healthy bleeding base. '
      'Wound bed preparation: TIME principle (Tissue debridement, Infection/inflammation control, Moisture balance, Edge advancement). '
      'Dressings chosen by exudate level, depth, location, infection presence: '
      'Alginates (calcium/sodium from seaweed) for moderate-heavy exudate, forms gel, hemostatic - change daily to every 3 days. '
      'Foams (polyurethane, silicone) for moderate exudate, thermal insulation, cushioning - change every 3-5 days. '
      'Hydrocolloids for light-moderate exudate, autolytic debridement, waterproof - change every 3-7 days. '
      'Hydrogels for dry wounds/slough, rehydrates, autolytic debridement - change daily to every 3 days. '
      'Silver dressings (nanocrystalline, silver sulfadiazine, silver nitrate) for infected wounds, broad-spectrum antimicrobial - short-term only, 2-4 weeks due to cytotoxicity concerns. '
      'Honey dressings (Manuka medical-grade UMF 10+ or 12+) for infected wounds, antibacterial, anti-inflammatory, debriding - alternative to silver, pH 3.5-4.5 creates acidic wound environment. '
      'Sucrose octasulfate (TLC-NOSF dressing, UrgoStart) for chronic DFU, MMP inhibitor - shown to improve healing rate by 60% vs foam. '
      'NPWT (negative pressure wound therapy / VAC) for large deep wounds, post-debridement, graft bed preparation. Settings: -125 mmHg continuous or intermittent, change every 48-72 hours. '
      'Antibiotic-impregnated bone cement (PMMA beads/spacers with gentamicin, vancomycin, tobramycin) for osteomyelitis, delivers high local antibiotic concentration. '
      'Odor-absorbent dressings (charcoal, metronidazole gel) for malodorous wounds. '
      'Hydrofiber (gelling fiber, Aquacel) for heavy exudate - forms gel, vertical wicking. '
      'Contact layer (silicone, paraffin gauze) for fragile wounds to prevent trauma on dressing change. '
      'Moist wound healing principle: wounds heal faster in moist environment (40% faster than dry). Avoid maceration of surrounding skin. '
      'Periwound skin protection: zinc oxide, barrier creams, silicone-based protectants. '
      'Advanced therapies: bioengineered skin substitutes (Apligraf living bilayered, Dermagraft dermal fibroblasts, OrCel, GraftJacket), '
      'platelet-rich plasma (PRP, autologous growth factors - prepare by centrifugation of patients blood), growth factors (becaplermin/PDGF gel 0.01% Regranex - apply daily, reduce healing time by 30%). '
      'Wound healing phases: hemostasis (platelet plug, clotting cascade), inflammation (neutrophils, macrophages days 1-5), '
      'proliferation (granulation tissue, angiogenesis, collagen deposition days 3-21), remodeling/maturation (collagen reorganization, wound contraction weeks 3-12). '
      'Chronic wounds are stuck in inflammatory phase. Debridement converts chronic wound to acute wound restarting normal healing. '
      'Matrix metalloproteinases (MMPs): elevated in chronic wounds (MMP-1, -2, -8, -9). TIMPs (tissue inhibitors) are decreased. '
      'Use MMP-modulating dressings (collagen, oxidized regenerated cellulose, TLC-NOSF) to rebalance protease activity. '
      'Cytokines in wound healing: PDGF (platelet-derived growth factor), VEGF (vascular endothelial growth factor angiogenesis), '
      'FGF (fibroblast growth factor), TGF-beta (collagen synthesis), EGF (epidermal growth factor), KGF (keratinocyte growth factor). '
      'Hypoxia-inducible factor 1-alpha (HIF-1a): key regulator of angiogenic response. Decreased in diabetic wounds. '
      'Biofilm: aggregates of bacteria (S. aureus, P. aeruginosa, anaerobes) embedded in extracellular polymeric matrix. Resistant to antibiotics and host defenses. '
      'Biofilm identification: slimy appearance, poor response to treatment, recurrent infection. Requires physical debridement for disruption. '
      'Anti-biofilm strategies: debridement, topical antimicrobials (cadexomer iodine, silver, honey, PHMB), biofilm-disrupting agents (xylitol, lactoferrin, EDTA). '
      'Wound culture: deep tissue biopsy is gold standard. Swab Levine technique (rotate swab in clean wound base after debridement) for superficial. Avoid swabbing pus. '

      'INFECTIONS AND ANTIBIOTICS: Assess IDSA/IWGDF severity. Obtain cultures BEFORE antibiotics (deep tissue biopsy best, swab less reliable). '
      'Do NOT use antibiotics for uninfected ulcers. '
      'Mild infection: oral antibiotics targeting gram-positives (cephalexin 500mg QID, clindamycin 300mg QID, amoxicillin-clavulanate 875/125mg BID, TMP-SMX DS BID). Duration 1-2 weeks. '
      'Moderate infection: empiric broad-spectrum (piperacillin-tazobactam 3.375-4.5g IV q6-8h preferred, alternatives: ertapenem 1g IV daily, imipenem 500mg IV q6h, moxifloxacin 400mg PO/IV daily). '
      'MRSA suspected: add vancomycin (trough 15-20), linezolid 600mg PO/IV q12h (good oral bioavailability), daptomycin 4-6mg/kg IV daily. '
      'Pseudomonas suspected (Asia/North Africa, warm climates, recent isolation, previous antibiotic use): add cefepime 2g IV q8h, ceftazidime 2g IV q8h, ciprofloxacin 750mg PO/400mg IV BID. '
      'In temperate climates, do NOT empirically cover Pseudomonas unless isolated within previous weeks. '
      'MDR organisms: consider ceftaroline, ceftolozane-tazobactam, ceftazidime-avibactam, meropenem-vaborbactam. '
      'Anaerobic coverage: metronidazole 500mg PO/IV q8h, clindamycin. Important for ischemia/gangrene. '
      'Severe infection: IV broad-spectrum, urgent surgical consultation within 24-48 hours. Source control is priority. '
      'Duration: 1-2 weeks for mild-moderate if responding well. Up to 3-4 weeks if severe or PAD. '
      'Do NOT continue antibiotics until wound heals - stop when infection resolves (no signs of inflammation). '
      'Osteomyelitis diagnosis: probe-to-bone test (metal probe reaches bone through ulcer - sensitivity 87%, specificity 83%), MRI (most sensitive imaging 90-100%), bone biopsy (gold standard, histology + culture). '
      'X-ray findings: periosteal reaction, osteolysis, cortical destruction, sequestrum, involucrum. Note: X-ray changes appear only after 30-50% bone destruction, 2-4 week lag. '
      'Nuclear imaging: WBC scan labeled with Tc-99m or In-111 combined with bone scan (most specific for osteomyelitis 80-90%). '
      'PET/CT with FDG: emerging, sensitivity 81-97%. '
      'Osteomyelitis treatment: surgical resection of infected bone + antibiotics (curative intent). '
      'Non-surgical osteomyelitis treatment (palliative or poor surgical candidate): prolonged antibiotics 6-12 weeks, success rate 60-70% without infected bone removal. '
      'After minor amputation with positive bone margin: antibiotics up to 3 weeks. Without bone resection: 6 weeks. '
      'Oral antibiotics with good bioavailability (linezolid, TMP-SMX, clindamycin, fluoroquinolones) can be as effective as IV (OVIVA trial). '
      'Follow-up minimum 6 months after completing antibiotics to confirm remission. Recurrence rate 20-30%. '
      'Biofilm: structured bacterial community resistant to antibiotics. Requires physical debridement for disruption. '
      'Topical antimicrobials (silver, honey, iodine, PHMB) can suppress biofilm. '
      'Debridement + biofilm-oriented topical strategies central. Systemic antibiotics reserved for invasive infection. '
      'Antibiotic resistance is widespread - culture-guided therapy preferred. '
      'Multi-drug resistant organisms are increasing: MRSA 30-50%, ESBL-producing Enterobacteriaceae 10-30%, Pseudomonas resistance 15-30%. '

      'CHARCOT NEUROARTHROPATHY: Acute: hot (temperature >2C difference from contralateral), red, swollen foot. '
      'Painless despite significant destruction. Midfoot collapse (rocker-bottom deformity). Can be mistaken for infection or DVT. '
      'Eichenholtz stages: 1=fragmentation (acute inflammation, swelling, X-ray: fragmentation, joint destruction, debris), '
      '2=coalescence (decreasing swelling, X-ray: new bone formation, sclerosis, absorption of debris), 3=reconstruction/remodeling (stable deformity, fibrous ankylosis, bony fusion). '
      'Diagnosis: X-ray shows joint destruction, fragmentation, dislocation, Lisfranc dislocation pattern. MRI shows bone marrow edema, joint effusion, sinus tracts. '
      'Charcot can be misdiagnosed in up to 25% of cases - key distinguishing features: absence of systemic signs, painless despite extensive destruction, bounding pedal pulses. '
      'Differential diagnosis: cellulitis (painful, systemic signs), DVT (painful, does not involve bone), gout, pseudogout, osteomyelitis (usually with ulcer). '
      'Treatment acute: total contact cast, strict non-weight-bearing until skin temperature normalizes (usually 8-12 weeks, can be 6+ months). '
      'Bisphosphonates (pamidronate, zoledronic acid) may reduce bone turnover and symptoms - off-label. '
      'Followed by custom therapeutic footwear with rocker sole, multi-density insoles, ankle-foot orthosis if needed. '
      'Chronic: stable rocker-bottom deformity, prominent plantar bones at risk for ulceration. '
      'Surgery for severe deformity, recurrent ulcers, or instability: midfoot exostectomy (remove bony prominence), arthrodesis (internal or external fixation), or reconstruction with realignment. '
      'Surgical complications: non-union 40%, infection, wound dehiscence, hardware failure, recurrent deformity. '
      'Contralateral foot develops Charcot in 30-50% within 5 years. '
      'Subtalar and ankle joint Charcot: more severe, may require hindfoot arthrodesis, more likely to progress to amputation. '

      'TEMPERATURE MONITORING: Normal foot temperature 82-92F (28-33C). Diurnal variation <1C. '
      'Asymmetry >2.2C (4F) between corresponding sites on opposite feet = inflammation. '
      'Daily self-monitoring reduces ulcer risk by 50-60% per IWGDF guidelines. '
      'StepGuard temperature feature helps track this. Dermal thermography. '
      'Infrared dermal thermometry: handheld device measures skin temperature within 1-2 seconds. '
      'Thermal imaging cameras: allow comparison of multiple foot regions simultaneously, sensitivity for detecting inflammation. '
      'Normal temperature gradient: forefoot 28-30C, arch 29-31C, heel 30-32C. '
      'Temperature should be measured at the same time each day, ideally after a 10-minute rest. '
      'Diabetic foot self-care: temperature monitoring is the earliest objective indicator of inflammation before visible changes. '

      'RISK STRATIFICATION (NICE/IWGDF/ADA): '
      'Low risk: normal sensation, palpable pulses, no deformity. Follow-up annually. '
      'Moderate risk: neuropathy OR absent pulses, no deformity. Follow-up every 3-6 months by podiatrist. '
      'High risk: neuropathy + absent pulses OR deformity OR previous ulcer/amputation OR renal replacement therapy. '
      'Follow-up every 1-2 months by specialist foot team. Custom footwear required. '
      'Active foot problem: open ulcer, spreading infection, gangrene, acute Charcot. Immediate referral to multidisciplinary team within 24 hours. '
      'Comprehensive foot exam annually for all diabetic patients: monofilament, vibration, pulses, footwear check, visual inspection. '
      'Patients at low risk can be screened by primary care. High-risk patients need specialist care. '
      'Renal disease and dialysis increase risk 10-fold. CVD and smoking are major risk factors. '
      'Previous foot ulcer: 40% recurrence rate within 1 year, 60% within 3 years. '
      'Structured preventive programs (education + screening + footwear + referral) reduce amputation rates by 45-85%. '
      'Diabetes UK: annual foot check for all diabetics, incorporate into Quality and Outcomes Framework. '
      'Screening frequency: low risk annually, moderate risk 3-6 months, high risk 1-2 months. '
      'Access to podiatry reduces ulcer incidence by 40-60%. '

      'BLOOD SUGAR CONTROL: Target HbA1c <7% (ADA), <7.5-8% for elderly/complex/comorbid patients. '
      'Pre-meal glucose 80-130 mg/dL (4.4-7.2 mmol/L), post-meal <180 mg/dL (10 mmol/L). '
      'Hypoglycemia <70 mg/dL (3.9 mmol/L). Hyperglycemia >250 mg/dL in DFU patients increases infection risk. '
      'New diabetes medications: SGLT2 inhibitors (empagliflozin 10-25mg, dapagliflozin 5-10mg, canagliflozin 100-300mg) reduce CV events but increase risk of Fournier gangrene and euglycemic DKA. '
      'SGLT2 inhibitors: benefits for heart failure, CKD progression, weight loss. '
      'GLP-1 agonists (semaglutide 0.5-2mg weekly, liraglutide 0.6-1.8mg daily, dulaglutide 0.75-1.5mg weekly, tirzepatide 2.5-15mg weekly) promote weight loss, CV protection. '
      'Consider stopping metformin with severe PAD/CLI due to lactate risk. '
      'Inpatient DFU management requires tight glucose control (insulin protocol). '
      'Glycemic variability is as important as HbA1c. Frequent monitoring. '
      'Hypoglycemia prevention: sulfonylureas (gliclazide, glimepiride) and insulin carry highest risk. '
      'DPP-4 inhibitors (sitagliptin, saxagliptin, linagliptin) are weight-neutral, low hypoglycemia risk. '
      'Time-in-range (TIR) from CGM: target >70% in range 70-180 mg/dL, <4% below 70 mg/dL, <1% below 54 mg/dL. '
      'Insulin therapy: basal (glargine U100/U300, degludec U100/U200, detemir), prandial (aspart, lispro, glulisine), premixed (70/30, 75/25, 50/50). '
      'Insulin pump (CSII) for type 1 diabetes with gastroparesis or labile control. '
      'Metabolic surgery (bariatric) for type 2 diabetes with BMI >35 and poor control. '

      'EXERCISE AND LIFESTYLE: Walking in sturdy comfortable shoes (not with open sores). '
      'Non-weight-bearing exercise: swimming, stationary cycling, arm ergometry, upper body strength training, seated exercises for active ulcers. '
      'Leg elevation when sitting (reduce edema), wiggle toes (improve microcirculation), ankle pumps (venous return). '
      'Avoid crossing legs (impairs circulation). Smoking cessation is single most effective intervention for PAD (50% risk reduction in amputation). '
      'Nutrition: adequate protein 1.0-1.5 g/kg body weight for wound healing, vitamins C 500-1000mg, D 2000 IU, zinc 40mg, arginine 4.5g, glutamine 7g supplementation may help. '
      'Malnutrition screening: MUST or SNAQ tool. Low albumin (<3.5 g/dL) correlates with poor healing. '
      'Obesity management: weight reduction (even 5-10%) reduces plantar pressure, improves glycemic control. '
      'Mediterranean diet: anti-inflammatory, CV protective. Avoid high glycemic index foods. '
      'Multidisciplinary team: podiatrist, endocrinologist, vascular surgeon, infectious disease, wound care nurse, orthotist, dietitian, physical therapist, psychologist. '
      'One amputation occurs every 20 seconds globally. 85% of amputations are preceded by foot ulcer. '
      'Structured patient education programs reduce ulcer risk by nearly 50%. '
      'Diabetes self-management education (DSME) improves HbA1c by 0.5-1%. '
      'Peer support groups improve adherence to foot care. '
      'Return to work after foot ulcer: median 8-12 weeks. After amputation: 30% return within 1 year. '
      'Driving: after right leg amputation requires adaptive equipment, typically 6-8 weeks recovery. '

      'FOOT SURGERY: Indications for surgery: infection drainage, debridement, revascularization, deformity correction, amputation, Charcot reconstruction. '
      'Amputation levels (from most distal): toe amputation (terminal Syme, toe disarticulation), ray amputation (toe+metatarsal head, partial foot), '
      'transmetatarsal (TMA), Lisfranc (tarsometatarsal disarticulation), Chopart (midtarsal disarticulation), Syme (ankle disarticulation), '
      'transtibial (below-knee BKA - 15cm from tibial plateau), knee disarticulation, transfemoral (above-knee AKA - 5cm above condyles). '
      'Guyton criteria for TMA: viable flap, palpable pulse or TBI>0.5, no infection. '
      'More distal amputation preferred when possible (preserves function, lower metabolic cost of walking). '
      'BKA vs AKA: BKA preserves knee, better rehab (80% ambulate); AKA for non-ambulatory, severe infection extending proximally, severe contracture. '
      'BKA energy cost: 40% more energy than normal walking. AKA: 60% more. '
      'Post-amputation: rigid dressing or IPOP (immediate post-operative prosthesis), stump shaping, desensitization, prosthesis fitting at 6-12 weeks. '
      'Phantom limb pain: 50-80% of amputees. Treatment: mirror box therapy, TENS, gabapentin, pregabalin, SCS. '
      'Gait training with prosthesis: parallel bars, walker, cane. '
      'Contralateral foot monitoring (50% develop problems within 2 years, 50% require contralateral amputation within 3-5 years). '
      'Diabetes and smoking increase amputation risk 3-6 fold. Limb salvage programs reduce major amputations by 50%. '
      'Revascularization preferred over primary amputation when limb viable. '
      'Assessment before amputation: perfusion (ABI, TBI, TcPO2), infection control, nutritional status (albumin, prealbumin), rehabilitation potential, social support. '
      'Minor amputation (toe, ray): preserves foot function, outpatient procedure, healing rate 70-85%. '
      'Major amputation (BKA, AKA): inpatient, longer recovery, higher morbidity, 50% survival at 3 years. '
      'Skin grafts: split-thickness (STSG) for superficial wounds on well-vascularized bed. Full-thickness (FTSG) for small deep defects on face/hands. '
      'Flap coverage: local flaps (random, axial, fasciocutaneous, muscle) for small-medium defects. Free flaps (free tissue transfer, microvascular anastomosis) for large complex wounds. '
      'Surgical debridement: scalpel, curette, rongeur for bone. Layered excision of necrotic tissue until healthy bleeding tissue. '
      'Tendon debridement: paratenon-preserving debridement. Exposed tendon without paratenon requires flap coverage. '
      'Bone biopsy: 3-5mm core through clean wound, separate aerobic/anaerobic culture and histopathology. '

      'DERMATOLOGICAL CONDITIONS: Xerosis (dry, scaly skin from autonomic neuropathy) - daily moisturizer with urea 10% or lactic acid 5-12%. '
      'Tinea pedis (athletes foot: interdigital scaling, maceration, itching) - terbinafine 1% cream daily x2 weeks, clotrimazole 1% cream, miconazole. '
      'Onychomycosis (thick, yellow, discolored nail) - oral terbinafine 250mg daily x12 weeks (liver function monitoring), topical ciclopirox 8% or efinaconazole 10% lacquer (lower efficacy). '
      'Fissures (heel cracks) - deep cracks prone to infection - debridement of callus edges, superglue or cyanoacrylate for deep fissures, urea 40% cream, Liquid/Vaseline. '
      'Bullosis diabeticorum (spontaneous blisters on feet/legs) - sterile drainage leave roof intact, prevent infection. '
      'Calluses - professional debridement only (do not cut at home). Sign of high pressure areas. Recur unless underlying pressure is offloaded. '
      'Digital ulcers from hammertoes/claw toes - toe spacers, silicone sleeves, custom shoes, consider flexor tenotomy. '
      'Ingrown toenails (onychocryptosis): professional care, partial nail avulsion with phenolization for recurrent (granulation tissue, infection). '
      'Diabetic dermopathy: brown atrophic spots on shins - benign, no treatment needed. '
      'Necrobiosis lipoidica: yellow-brown waxy plaques on shins, telangiectasias, can ulcerate. Treatment: topical steroids, tacrolimus, pentoxifylline, PUVA. '
      'Acanthosis nigricans: velvety dark patches in skin folds - marker of insulin resistance. '
      'Granuloma annulare: ring-shaped papules on extremities, generalized form associated with diabetes. '
      'Scleredema diabeticorum: thickening of upper back skin, non-pitting, rare. '
      'Lipodystrophy: loss of subcutaneous fat at insulin injection sites, rotate injection sites. '
      'Lipohypertrophy: accumulation of fat at repeated insulin injection sites - rotate and inspect. '
      'Skin care: avoid harsh soaps, use mild pH-balanced soap (pH 5.5), pat dry, moisturize within 3 minutes of bathing. '
      'Deep vein thrombosis (DVT) prophylaxis for immobilized inpatients: LMWH (enoxaparin 40mg daily), compression stockings, early mobilization. '
      'Wells criteria for DVT: active cancer, paralysis, recent surgery, calf swelling >3cm, pitting edema, collateral veins, alternative diagnosis less likely. '
      'Cellulitis vs venous stasis dermatitis: both red, swollen legs. Cellulitis: warm, tender, unilateral, systemic signs. '
      'Venous stasis: bilateral, pruritic, hemosiderin staining, varicose veins, responds to compression. '

      'IMAGING: X-ray: first-line, 3 views (AP, lateral, oblique), serial every 2-4 weeks if osteomyelitis suspected (delayed findings 2-4 weeks). '
      'Look for: periosteal reaction, osteolysis, cortical destruction, sequestrum, involucrum, Charcot changes, joint dislocation. '
      'MRI: best sensitivity/specificity for osteomyelitis (90-100%), abscess, sinus tracts, Charcot. T1 hypointense, STIR/T2 hyperintense bone marrow edema. '
      'MRI with gadolinium: distinguishes abscess from phlegmon, necrotic tissue from viable. '
      'CT: better cortical detail, useful for surgical planning, bone destruction evaluation, sequestrum identification. '
      'CT angiography (CTA): pre-revascularization mapping of arterial tree - lower extremities run-off. '
      'MR angiography (MRA): non-invasive alternative to CTA, but may overestimate stenosis in distal vessels. '
      'PET/CT with FDG: emerging for infection localization, sensitivity 81-97%. Can help distinguish Charcot from osteomyelitis. '
      'Ultrasound: abscess detection, soft tissue gas (emphysematous infection), fluid collections, pseudoaneurysm. '
      'Duplex ultrasound: arterial stenosis/occlusion, peak systolic velocity, waveform analysis (monophasic = PAD). '
      'Nuclear medicine: three-phase bone scan (Tc-99m MDP) - sensitive but not specific. WBC scan (Tc-99m HMPAO labeled) combined with bone marrow scan - most specific. '
      'Digital subtraction angiography (DSA): gold standard for arteriography, invasive, contrast risk. '
      'Arteriography/CTA/MRA: pre-revascularization mapping. '
      'Repeat imaging: follow-up every 2-4 weeks to monitor wound progression. '
      'Wounds that fail to improve >50% area reduction after 4 weeks of standard care need advanced therapies and re-evaluation of diagnosis. '
      'Contrast-induced nephropathy risk: pre-hydrate, minimize contrast volume, use iso-osmolar contrast, hold metformin 48h. '
      'Imaging algorithm: X-ray first, then MRI if osteomyelitis suspected, then CTA/MRA if revascularization planned. '

      'ADJUNCTIVE THERAPIES: '
      'Hyperbaric oxygen therapy (HBO): 100% O2 at 2-2.5 ATA for 90-120 minutes daily, 20-40 sessions. Evidence: controversial. '
      'Wagner 3+ DFU with ischemia. Mechanisms: neovascularization, fibroblast proliferation, leukocyte bactericidal activity, collagen synthesis. '
      'Contraindications: untreated pneumothorax, severe COPD, bleomycin, cisplatin, doxorubicin. '
      'NPWT (VAC): 125 mmHg continuous or intermittent, change every 48-72 hours. Promotes granulation, reduces wound volume, manages exudate, reduces edema. '
      'Contraindications to NPWT: untreated osteomyelitis, necrotic tissue with eschar, exposed vessels/organs, malignancy in wound. '
      'NPWT with instillation (NPWTi-d): adds topical solutions (saline, antiseptics, antibiotics) soak for 5-20 minutes, then NPWT. For biofilm, heavily infected wounds. '
      'Becaplermin (Regranex): PDGF gel 0.01% - increases complete healing rate by 30%, apply once daily. Black box warning: increased malignancy risk with 3+ tubes. '
      'Bioengineered skin: Apligraf (living bilayered neonatal foreskin keratinocytes + fibroblasts in bovine collagen) - apply weekly, 8 weeks. '
      'Dermagraft (living neonatal dermal fibroblasts on polyglactin mesh) - apply every 1-2 weeks, 8 weeks. '
      'Oasis (porcine SIS extracellular matrix), MatriStem (porcine urinary bladder ECM), Integra (bovine collagen + silicone). '
      'Amniotic membrane grafts (dehydrated or cryopreserved, Epifix, AmnioGraft, Grafix) - growth factors, anti-inflammatory, stem cells. '
      'Platelet-rich plasma (PRP): concentrated growth factors from patients own blood, 3-8x baseline, injected or applied topically with thrombin activation. '
      'PRP preparation: whole blood centrifuge at 200-300g for 10-15 minutes, collect buffy coat. Requires 30-60 mL blood. '
      'Electrical stimulation: pulsed electromagnetic field (PEMF), high-voltage pulsed current (HVPC) 100-150V, 100 pps. May promote healing. '
      'TENS for pain management in neuropathy: 50-100 Hz, 100-250 mS pulse width, 30 minutes daily. '
      'Low-frequency ultrasound debridement (MIST therapy): 40 kHz, non-contact, saline mist, debrides and stimulates cellular activity. '
      'Maggot debridement therapy: sterile Lucilia sericata larvae applied 3-5 days, consume necrotic tissue and bacteria, 5-10x more effective than conventional debridement. '
      'Larvae secrete allantoin, ammonia, proteolytic enzymes that dissolve necrotic tissue. '
      'G-CSF (filgrastim, lenograstim): 5-10 mcg/kg/day for 7-14 days, may reduce amputation in severe infection, reduces antibiotic need. '
      'Pentoxifylline (Trental) 400mg TID: improves RBC deformability, reduces blood viscosity, may help PAD (modest benefit for claudication). '
      'Prostaglandin analogs (alprostadil, iloprost, beraprost): IV prostacyclin, vasodilation, for CLI not amenable to revascularization. '
      'Low-level laser therapy (LLLT): 600-1000nm, 1-6 J/cm2, may stimulate fibroblast proliferation and collagen synthesis. '
      'PUVA therapy (psoralen + UVA): for necrobiosis lipoidica. '
      'Botulinum toxin A (Botox): intradermal injection for Raynaud phenomenon, improves microcirculation. '
      'Consider advanced therapies only after standard care failure (4-6 weeks of appropriate offloading, debridement, moist wound therapy, infection control, and revascularization if needed). '

      'WOUND ASSESSMENT AND MONITORING TOOLS: '
      'PUSH tool (Pressure Ulcer Scale for Healing): 3 subscales - area, exudate, tissue type. Score 0-17, measure weekly. Validated for DFU. '
      'BWAT (Bates-Jensen Wound Assessment Tool): 13 items including size, depth, edges, undermining, necrotic tissue, exudate type/amount, surrounding skin, edema, granulation, epithelialization. '
      'RESVECH (Resultados en la Evaluacion de las heridas): wound healing assessment tool validated in Spanish. '
      'Wound photography: standardized distance 30-50cm, perpendicular, right angle, reference scale (ruler), consistent lighting. '
      '3D wound measurement: digital planimetry software (Imito, SilhouetteConnect, MolecuLight i:X) - more accurate than ruler. '
      'Thermal imaging: FLIR camera, detect inflammation 2-3C difference. '
      'Fluorescence imaging (MolecuLight i:X): detect bacterial load >10^4 CFU/g, autofluorescence of bacterial porphyrins. '
      'Transcutaneous oxygen measurement (TcPO2): electrode heated to 44C, measure oxygen tension. Normal >50 mmHg, borderline 30-50, ischemic <30. '
      'Near-infrared spectroscopy (NIRS, INVOS): measure tissue oxygen saturation (StO2). Non-invasive, continuous. '
      'Laser Doppler flowmetry/fluximetry: measure microvascular blood flow. '
      'Skin perfusion pressure (SPP): minimum pressure required to restore blood flow after occlusion. Normal >50 mmHg. '
      'Aortogram with run-off for pre-surgical planning. '
      'Wound healing trajectory: wound area decrease should be 10-20% per week. Linear healing rate: 0.5-1.0 mm/day. '
      'Trajectory reassessment: if wound not reduced >40% area at 4 weeks, reconsider diagnosis, treatment, and advanced therapies. '

      'NUTRITION AND SUPPLEMENTS FOR WOUND HEALING: '
      'Protein: 1.0-1.5 g/kg body weight per day (wound healing increases nitrogen demand). 1.5-2.0 g/kg for large wounds or burns. '
      'Arginine: 4.5-7.0 g/day. Precursor for nitric oxide (vasodilation, angiogenesis), collagen synthesis, immune function. '
      'Glutamine: 7-15 g/day. Fuel for immune cells (lymphocytes, macrophages), enterocytes. Maintains gut barrier. '
      'Vitamin C (ascorbic acid): 500-2000 mg/day. Cofactor for collagen cross-linking (hydroxyproline, hydroxylysine), antioxidant. '
      'Scurvy: impaired wound healing, perifollicular hemorrhages, ecchymosis, gingival hyperplasia. '
      'Vitamin D: 2000-4000 IU/day (maintain serum 25-OH D >50 nmol/L). Immune modulation, antimicrobial peptide production (cathelicidin). '
      'Vitamin A: 10,000-25,000 IU/day (short-term). Promotes epithelialization, collagen synthesis. Antagonizes steroid effects on wound healing. '
      'Zinc: 30-50 mg elemental zinc/day (with copper 2 mg to prevent deficiency). Cofactor for collagen synthesis, DNA synthesis, cell proliferation. '
      'Copper: 2-3 mg/day. Cofactor for lysyl oxidase (collagen cross-linking), angiogenesis. '
      'Iron: maintain ferritin >50 ng/mL, transferrin saturation >20%. Cofactor for oxygen transport, collagen hydroxylation. '
      'Selenium: 55-200 mcg/day. Antioxidant (glutathione peroxidase), thyroid function. '
      'Vitamin B complex: B1 (thiamine 100mg), B6 (pyridoxine 50mg), B12 (1000mcg) - for neuropathy support, energy metabolism. '
      'Biotin: 30-100 mcg/day. Important for glucose metabolism, fatty acid synthesis. '
      'Vitamin E (alpha-tocopherol): 400-800 IU/day. Antioxidant, but high doses may impair collagen synthesis. '
      'Mixed amino acids: commercial wound healing supplements (Juven, Ensure, Nepro, Glucerna) generally contain arginine, glutamine, HMB, vitamin C, zinc. '
      'HMB (beta-hydroxy-beta-methylbutyrate): 2-3 g/day. Reduces muscle wasting, promotes protein synthesis. '
      'Creatine: 5 g/day. Improves muscle function. May reduce glucose levels. '
      'Omega-3 fatty acids (EPA/DHA): 2-4 g/day. Anti-inflammatory, immune modulation, CV protection. '
      'Optimal nutrition: 30-35 kcal/kg/day total energy. Protein 1.2-1.5 g/kg. '
      'Hydration: 30-35 mL/kg/day. Dehydration impairs wound healing. '
      'Enteral nutrition (tube feeding) indicated if oral intake <60% of requirements for >7 days. '
      'Parenteral nutrition if GI tract non-functional. '
      'Malnutrition universal screening tool (MUST) for all DFU inpatients. '
      'Serum prealbumin is best marker of current nutritional status (half-life 2-3 days). Goal >20 mg/dL. '
      'Serum albumin: reflects long-term status (half-life 20 days). Goal >3.5 g/dL. '
      'HbA1c <8% recommended during wound healing - strict control reduces infection. '
      'Overnutrition (obesity) increases infection risk and plantar pressure. Balanced caloric intake with emphasis on protein. '

      'PAIN MANAGEMENT: '
      'WHO analgesic ladder chronic pain: step 1 non-opioids (NSAIDs, acetaminophen), step 2 weak opioids (tramadol, codeine), step 3 strong opioids (morphine, oxycodone, fentanyl). '
      'Neuropathic pain first-line: pregabalin 150-600mg/day or duloxetine 60-120mg/day. '
      'Gabapentin 900-3600mg/day (titrate slowly: 300mg day 1, 300 BID day 2, 300 TID day 3). Renally eliminated - adjust for CKD. '
      'TCA options: amitriptyline 10-75mg at bedtime, nortriptyline 25-100mg, desipramine 25-100mg. Lower side effect profile than amitriptyline. '
      'Anticonvulsants: lamotrigine 200-400mg, topiramate 100-400mg, oxcarbazepine 600-1800mg. '
      'Topical: capsaicin 0.075% cream (multiple daily applications), capsaicin 8% patch (applied by physician every 3 months). '
      'Lidocaine 5% patch: apply 12 hours on, 12 hours off. Minimal systemic absorption. '
      'Doxepin 5% cream: antihistamine, topical anesthetic for burning neuropathic pain. '
      'NMDA antagonists: ketamine (topical 2-10%, IV for refractory), dextromethorphan (with quinidine for pseudobulbar affect). '
      'Opioids for neuropathic pain: tramadol 200-400mg/day, tapentadol 100-500mg/day (SNRI + mu agonist). '
      'Cannabinoids: nabilone, dronabinol. Limited evidence for DPN. Legal status varies. '
      'Nociceptive pain (ulcer itself): acetaminophen 1000mg TID, NSAIDs cautiously (naproxen 500mg BID, ibuprofen 600mg QID) - renal risk. '
      'Pain from dressing changes: pre-medicate 30 minutes before, atraumatic dressings (silicone). '
      'Procedural pain: EMLA cream, lidocaine injection, nitrous oxide, monitored sedation. '
      'Chronic pain syndromes: fibromyalgia overlap with DPN requires multimodal approach. '
      'Pain catastrophizing: cognitive behavioral therapy, pain education, graded motor imagery. '
      'Multidisciplinary pain management: physical therapy, occupational therapy, psychology, pain specialist. '
      'Non-pharmacological: acupuncture (moderate evidence), biofeedback, hypnosis, relaxation techniques, TENS, massage. '
      'Pain diary: track intensity (0-10 NRS), quality, location, triggers, relief. Guides treatment. '
      'Depression and anxiety co-occur with chronic pain in 30-50% - treat concurrently. '

      'PSYCHOLOGICAL AND SOCIAL ASPECTS: '
      'Depression in DFU patients: 30-50% prevalence. Major risk factor for poor outcomes. Screen with PHQ-9 or HADS. '
      'Anxiety: 25-40%. Fear of amputation, social isolation, loss of independence. '
      'Diabetes distress: emotional burden of self-management, regimen distress. Distinguish from depression. '
      'Quality of life: DFU reduces QoL more than most diabetic complications. Pain, odor, exudate, dressing changes, mobility limitations, footwear restrictions. '
      'Social isolation: reduced social activity due to odor, bulky dressings, offloading devices, mobility limitation. '
      'Sexual dysfunction: affects 50% of diabetics with neuropathy. Can contribute to depression. '
      'Body image disturbance: especially after amputation. Limb loss affects self-identity. '
      'Fear of amputation: catastrophic fear that motivates or paralyzes - therapeutic discussion. '
      'Self-efficacy: belief in ability to perform foot care. Higher self-efficacy -> better outcomes. '
      'Coping strategies: problem-focused (active self-care) vs emotion-focused (avoidance). '
      'Cognitive impairment: 20-30% of elderly diabetic patients. Affects ability to perform foot care. Requires caregiver involvement. '
      'Health literacy: many patients do not understand basic foot care instructions. Teach-back method. '
      'Cultural considerations: barefoot customs (India, Middle East, Africa), home remedies, diet, gender roles in care-seeking. '
      'Social support: single/widowed patients have worse outcomes. Involve family caregivers in education. '
      'Financial toxicity: cost of dressings, offloading devices, transportation to appointments, lost work. '
      'Return to work: after minor amputation: 6-12 weeks. After major amputation: 30-50% return within 1 year. '
      'Psychological interventions: cognitive behavioral therapy, motivational interviewing, peer support groups, mindfulness-based stress reduction. '
      'Antidepressants in DFU: SSRIs (citalopram, sertraline, escitalopram) first-line. SNRIs (duloxetine) also treat neuropathic pain. '
      'Suicide risk: elevated in chronic DFU with pain. Assess in clinic. Refer to mental health. '

      'TELEMEDICINE AND DIGITAL HEALTH: '
      'Remote wound monitoring: patients take photos at home, upload to provider. Reduce clinic visits by 50%. '
      'Store-and-forward telemedicine: asynchronous image + data review by wound specialist. '
      'Real-time video consultation: synchronous visit for wound assessment and patient education. '
      'Wearable sensors: smart socks with pressure sensors detect at-risk areas. Temperature sensors monitor inflammation. '
      'Activity monitors (Fitbit, Actigraph): measure adherence to offloading, step count, sleep. '
      'Smart bandages: pH sensors, temperature sensors, moisture sensors, antibiotic eluting. '
      'Continuous glucose monitors (CGM, Dexcom G6/G7, Freestyle Libre 2/3): real-time glucose monitoring, remote sharing. '
      'AI in wound care: automated wound measurement (ImageMetry, Tissue Analytics), '
      'wound classification algorithms (Wagner, University of Texas), infection detection from photos, healing trajectory prediction. '
      'Deep learning for DFU detection: convolutional neural networks trained on wound photographs. Sensitivity 90-95%, specificity 85-90%. '
      'Mobile apps for foot care: StepGuard providing comprehensive diabetic foot monitoring. '
      'Electronic health records: wound-specific templates, PUSH score tracking, automated risk stratification. '
      'Barriers to telemedicine: digital literacy, internet access, camera quality, reimbursement, regulatory. '
      'COVID-19 impact: accelerated telemedicine adoption. DFU telemedicine maintained care quality. '
      'Remote patient monitoring (RPM): Medicare reimbursement for chronic wound monitoring. '
      'Digital therapeutics: prescription digital interventions for diabetes management, foot care education. '

      'SPECIFIC POPULATIONS: '
      'End-stage renal disease (ESRD) on dialysis: 10-fold increased risk of foot ulceration and amputation. Factors: peripheral edema, malnutrition, hypotension during dialysis affecting perfusion, vascular calcification, immunodeficiency. '
      'Dialysis access management: avoid lower extremity AV fistulas in patients with PAD. '
      'Renal transplant: persistent high risk despite restored renal function. Maintain post-transplant foot surveillance. '
      'Elderly (>75 years): higher prevalence of PAD, cognitive impairment, falls risk, social isolation, polypharmacy. '
      'Elderly goals of care: may prioritize quality of life, independence over aggressive wound care. DiscussAdvanced directives for major amputation. '
      'Palliative wound care for non-healable wounds: odor control, pain management, exudate management, prevention of infection. Goals: comfort, dignity, quality of life. '
      'Pediatric/adolescent diabetes: predominantly type 1. Diabetic foot rare but devastating. Early education on foot care. '
      'Pregnancy in diabetes: increased risk of hypoglycemia, pregnancy-specific insulin resistance. Foot care still important. '
      'Immunocompromised (HIV, transplant, chemotherapy): atypical infections, impaired healing, need longer antibiotic courses, fungal infections more common. '
      'Rheumatoid arthritis + diabetes: increased amputation risk. Foot deformities from RA compounding neuropathy. '
      'Mental illness (schizophrenia, bipolar): higher diabetes prevalence, worse glycemic control, higher amputation rates. Need intensive support. '
      'Homeless/unstably housed: unable to perform foot care, adhere to offloading, store medications. Social work intervention critical. '
      'Substance use disorder (alcohol, opioids, cocaine): wound healing impaired, non-adherence, lost to follow-up. '
      'Cocaine/amphetamines cause severe vasoconstriction and tissue ischemia. '
      'Bariatric population: obesity makes self-foot inspection difficult, plantar pressures elevated. Weight loss reduces risk. '
      'Amputation after bariatric surgery: still possible but risk reduced. Nutritional deficiencies (B12, iron, vitamin D) impair healing. '

      'HEALTH ECONOMICS: '
      'Direct cost of DFU in US: \$9-13 billion annually. Per episode: \$10,000-50,000. '
      'Cost of major amputation: \$50,000-80,000 initial hospitalization, \$500,000 lifetime. '
      'Cost per patient with DFU: 5x higher than diabetic without foot complications. '
      'Amputation cost: 2-3x higher than limb salvage. '
      'Cost-effectiveness of prevention programs: every \$1 invested saves \$3-8 in amputation costs. '
      'Cost of NPWT: \$50-150 per dressing change vs standard dressings \$5-30. NPWT shown to be cost-effective if reduces healing time by >30%. '
      'Cost of bioengineered skin: \$1,000-3,000 per application vs \$100 standard care. '
      'Cost-effectiveness of TCC: \$1,500-3,000 total for healing episode vs \$8,000-15,000 for removable walker due to slower healing. '
      'Cost of advanced therapies: HBO \$300-800 per session, 20-40 sessions. '
      'Yearly screening cost per patient: \$50-200. '
      'Reduces amputation: screen high-risk annually, low-risk every 3-6 months. '
      'Health system impact: DFU patients use 2-3x more in-patient days. '
      'Long-term care after amputation: 30-50% require nursing home placement. '
      'Productivity loss: DFU leads to 2-4 months lost work per episode. '
      'WHO estimates: 15-25% of all diabetes healthcare expenditure is for foot complications. '
      'Cost-effective interventions ranked: smoking cessation, glucose control, foot screening, therapeutic footwear, patient education, multidisciplinary care. '

      'GUIDELINES AND STANDARDS OVERVIEW: '
      'IWGDF (International Working Group on Diabetic Foot): practical guidelines updated every 2 years. Most comprehensive international guidance. Chapters: classification, diagnosis, PAD, infection, offloading, wound healing, Charcot. '
      'ADA Standards of Medical Care in Diabetes: Section 12 Retinopathy, Neuropathy, Foot Care. Updated annually in January. '
      'NICE Guidelines (UK): NG19 Diabetic foot problems: prevention and management. Risk stratification, multidisciplinary team, referral pathways. '
      'IDSA (Infectious Diseases Society of America): guidelines for DFI diagnosis and treatment. Uses IDSA/IWGDF infection classification. '
      'WUWHS (World Union of Wound Healing Societies): consensus documents on wound infection, exudate management, compression. '
      'EWMA (European Wound Management Association): position documents on wound bed preparation, biofilms, debridement. '
      'SVS (Society for Vascular Surgery): WIfI classification, guidelines for management of PAD, CLI, amputation prevention. '
      'AHA/ACC (American Heart Association/American College of Cardiology): guidelines for PAD management. '
      'TCO (Tropical Countries guidelines): modified IWGDF for resource-limited settings. '
      'WHO Global Diabetes Compact: targets 80% foot screening coverage, 50% reduction in amputations by 2030. '
      'St. Vincent Declaration (1989): first international call to reduce diabetes-related amputations by 50%. Most European countries have not achieved this. '
      'Scottish Diabetes Foot Action Group (SDFAG): national care pathway, annual foot surveillance with traffic light system. '

      'COMPLICATION PREVENTION AND RECURRENCE: '
      'After ulcer healing: lifetime protective footwear, custom insoles with metatarsal pads, rocker sole. '
      'Footwear should be prescribed by orthotist, replaced annually. '
      'Education: verbal + written + demonstration (teach-back method). '
      'Exercise: range of motion, stretching (Achilles, hamstrings), balance training (reduce fall risk). '
      'Smoking cessation: counseling, nicotine replacement (patch, gum, lozenge), varenicline, bupropion. '
      'Weight management: 5-10% weight loss reduces plantar pressure. '
      'CVD risk management: blood pressure <130/80, LDL <70, HbA1c <7%. '
      'Foot care compliance: long-term adherence is poor (30-50% at 1 year). Motivational interviewing. '
      'Reassessment: risk status can change. Re-screen annually at minimum. '
      'Recurrence prevention checklist: proper shoes, daily self-inspection, regular podiatry, glycemic control, weight, smoking, physical activity. '
      'Temperature monitoring: daily home monitoring reduces recurrence by 50%. '

      'StepGuard app has 9 tools: daily checkup checklist, touch test (monofilament), temperature measurement, '
      'foot photo AI analysis, risk assessment questionnaire (2 versions), history with search/filter, '
      'doctor report with PDF and WhatsApp export, prevention tips, AI chat. '
      'Also: profile management, 3 daily reminder notifications (9am, 3pm, 9pm), dark mode, 3 languages (Arabic/English/French). '
      'Answer all questions with evidence-based information. Provide complete, thorough, detailed answers like a medical encyclopedia. '
      'If unsure, recommend consulting a healthcare professional. '
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
