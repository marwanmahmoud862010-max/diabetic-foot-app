import 'package:flutter/material.dart';
import 'language_service.dart';
import 'route_transition.dart';
import 'widgets/dark_mode_toggle.dart';

class ResearchesScreen extends StatefulWidget {
  const ResearchesScreen({super.key});

  @override
  State<ResearchesScreen> createState() => _ResearchesScreenState();
}

class _ResearchesScreenState extends State<ResearchesScreen> {
  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    super.dispose();
  }

  double _fontSize = 16;

  void _openDetail(int index) {
    final research = _researches[index];
    pushPage(context, StatefulBuilder(
      builder: (context, setInnerState) {
        return Scaffold(
          appBar: AppBar(
            title: Text(research['institution'] ?? '', style: const TextStyle(fontSize: 14)),
            actions: [
              IconButton(
                icon: const Icon(Icons.text_decrease),
                onPressed: () => setInnerState(() => _fontSize = (_fontSize - 2).clamp(10, 36)),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase),
                onPressed: () => setInnerState(() => _fontSize = (_fontSize + 2).clamp(10, 36)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      research['date'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SelectableText(
                  research['content'] ?? '',
                  style: TextStyle(fontSize: _fontSize, height: 1.6),
                ),
              ],
            ),
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('researches')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 10,
          itemBuilder: (context, index) => _buildResearchCard(index),
        ),
      ),
    );
  }

  Widget _buildResearchCard(int index) {
    final research = _researches[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        research['institution'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${LanguageService.t('research_date')}: ${research['date'] ?? ''}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(Icons.arrow_back_ios, color: Colors.teal, size: 16),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<Map<String, String>> _researches = [
    {
      'institution': 'ScienceDirect — Systematic Review',
      'date': '2025',
      'content': 'Epidemiology, Pathophysiology, and Management of Diabetic Foot Ulcers\n\n'
          'A comprehensive systematic review of 286 studies on diabetic foot ulcers (DFUs). DFUs affect over 6% of diabetics worldwide, causing major morbidity and disability. '
          'The review covers epidemiology, pathophysiology (hyperglycemia driving neuropathy, vasculopathy, and inflammation), and modern management strategies including '
          'bioengineered skin scaffolds, recombinant growth factors, stem cell therapies, nanotechnology-based delivery systems, and negative-pressure wound therapy. '
          'The future lies in AI, wearable biosensors, and telemedicine for personalized diabetic foot care.\n\n'
          'Source: ScienceDirect, 2025',
    },
    {
      'institution': 'Journal of Medical Internet Research (JMIR)',
      'date': '2025',
      'content': 'Diabetic Foot Ulcer Classification Models Using Artificial Intelligence and Machine Learning\n\n'
          'A systematic review registered in PROSPERO (CRD42022308248) that searched MEDLINE, Scopus, Web of Science, and IEEE Xplore for AI/ML models classifying diabetic foot ulcers. '
          'The review followed IWGDF standardized methodology and identified various machine learning approaches for ulcer classification, '
          'including deep learning models for wound assessment, severity grading, and risk stratification. '
          'The study highlights how AI can revolutionize diabetic foot care through automated detection and monitoring.\n\n'
          'Source: JMIR, 2025',
    },
    {
      'institution': 'Springer Nature — Diabetology & Metabolic Syndrome',
      'date': '2025',
      'content': 'Integrative Biomarker Analysis in Diabetic Foot: Lipids, Cellular Integrity, and Hydration Balance\n\n'
          'A case-control study with 33 T2DM patients and 37 non-diabetic controls. The study analyzed bioimpedance-derived metrics (phase angle, extracellular water ratio) '
          'alongside lipid profiles. Key findings: Low LDL levels correlated with impaired cellular function. Phase angle negatively correlated with DFU risk (p=0.005). '
          'HDL positively correlated with fluid regulation markers. The CONUT index highlighted malnutrition\'s impact. '
          'LDL and phase angle are identified as critical biomarkers for DFU risk assessment.\n\n'
          'Source: Springer Nature, 2025',
    },
    {
      'institution': 'NCBI StatPearls — National Institutes of Health',
      'date': '2025',
      'content': 'Diabetic Foot Care — Clinical Guidelines\n\n'
          'A comprehensive clinical guide for healthcare professionals on proper diabetic foot care. Covers the structured clinical process essential for limb preservation. '
          'Topics include diabetic neuropathy, microvascular disease, biomechanical abnormalities, ulceration risk, infection prevention, and amputation prevention. '
          'Emphasizes comprehensive dermatological, vascular, neurological, and musculoskeletal assessment; early detection of preulcerative lesions; '
          'protective footwear; and patient education. Interprofessional collaboration is key for high-risk patients.\n\n'
          'Source: StatPearls Publishing, Updated September 2025',
    },
    {
      'institution': 'ScienceDirect — Current Research in Microbial Sciences',
      'date': '2026',
      'content': 'A Longitudinal Profiling of Microbiome of Diabetic Foot Ulcers\n\n'
          'A longitudinal microbiome analysis of 30 diabetic individuals using 16S rRNA-based metagenomics. '
          'Key findings: Pseudomonas, Escherichia, and Prevotella dominated DFU microbial communities. '
          'Healed DFUs were enriched in Alcaligenes, while worsened DFUs showed increased Enterococcus. '
          'Amputated patients had high Escherichia and reduced Staphylococcus. '
          'High HbA1c levels correlated with more Pseudomonas and Acinetobacter. '
          'The study reveals how microbial communities influence wound healing outcomes.\n\n'
          'Source: ScienceDirect, 2026',
    },
    {
      'institution': 'Frontiers in Pharmacology',
      'date': '2026',
      'content': 'A Comprehensive Review on Diabetic Foot Ulcer: Vascular Insufficiency, Impaired Immune Response, and Delayed Wound Healing\n\n'
          'A narrative review from Kampala International University exploring the complex pathophysiology of DFUs. '
          'Focuses on the interplay between peripheral neuropathy, vascular insufficiency, and weakened immune response. '
          'Reviews therapeutic approaches including wound debridement, advanced dressings, offloading techniques, glycemic control, '
          'growth factor therapy, hyperbaric oxygen, and negative pressure wound therapy. '
          'Highlights promising advances in bioengineered skin substitutes, smart dressings, and regenerative medicine. '
          'Emphasizes multidisciplinary care involving vascular surgeons, podiatrists, endocrinologists, and wound care specialists.\n\n'
          'Source: Frontiers, 2026',
    },
    {
      'institution': 'Heliyon — ScienceDirect (Bibliometric Analysis)',
      'date': '2024',
      'content': 'Bibliometric Analysis of Systematic Review and Meta-Analysis on Diabetic Foot Ulcer\n\n'
          'Analyzed 334 meta-analyses and systematic reviews on diabetic foot ulcers from the Web of Science database. '
          'Found rapid growth in publications (nearly 6-fold since 2016). Top researching countries: USA, China, Netherlands, England, Australia. '
          'Seven main topics identified: Interventions (59%), Risk factors and Prevention (22%), Epidemiology (6%), Cost-effectiveness (5%), '
          'Long-term prognosis (3%), Quality of life (3%), Economic burden (2%). '
          'Footwear, offloading, multidisciplinary care, hyperbaric oxygen, and negative pressure therapy are key interventions.\n\n'
          'Source: Heliyon, Volume 10, March 2024',
    },
    {
      'institution': 'International Wound Journal — Wiley',
      'date': '2023',
      'content': 'Most Individuals with Diabetes-Related Foot Ulceration Do Not Meet Dietary Consensus Guidelines for Wound Healing\n\n'
          'A study funded by NIH (R01 DK124789) and the National Health and Medical Research Council of Australia. '
          'Found that most patients with diabetic foot ulcers do not meet the dietary consensus guidelines for wound healing. '
          'Nutritional status plays a critical role in wound healing outcomes. The study emphasizes the need for nutritional assessment '
          'and intervention as part of comprehensive diabetic foot care to improve healing rates and reduce complications.\n\n'
          'Source: International Wound Journal, Wiley, 2023 (PMCID: PMC37950409)',
    },
    {
      'institution': 'Diabetic Foot Consortium — Biomarker Platform Study',
      'date': '2025-2026',
      'content': 'The Diabetic Foot Consortium Biomarker Platform Study\n\n'
          'An innovative clinical trial design using a master protocol framework to evaluate multiple potential therapies simultaneously. '
          'The platform study approach enables more rapid discovery of critical new disease-modifying therapies for diabetic foot complications. '
          'This consortium brings together multiple research institutions to accelerate biomarker identification and therapeutic development, '
          'aiming to reduce the burden of diabetic foot ulcers through early detection and personalized treatment strategies.\n\n'
          'Source: Diabetic Foot Consortium / SAGE Journals, 2025-2026',
    },
    {
      'institution': 'DelveInsight — Pipeline Analysis Report',
      'date': '2026',
      'content': 'Diabetic Foot Ulcers Pipeline 2026: Clinical Trials and Emerging Therapies\n\n'
          'A comprehensive pipeline analysis of emerging therapies for diabetic foot ulcers. Key developments include:\n'
          '- Kane Biotech: FDA-cleared revyve® Antimicrobial Wound Gel for DFU healing\n'
          '- Celularity Inc.: Phase 2 trial of PDA-002 (placenta-derived regenerative therapy) showing positive results\n'
          '- Eluciderm Inc.: FDA clearance for ELU-42 topical spray for DFU\n'
          '- BioStem Technologies: BR-AM-DFU clinical trial for Vendaje® amniotic membrane\n'
          '- ION: Phase 2 trial of Purified Exosome Product (PEP™) for DFU treatment\n'
          'Multiple novel therapies are advancing through clinical trials, offering hope for improved wound healing.\n\n'
          'Source: DelveInsight Pipeline Report, June 2026',
    },
  ];
}
