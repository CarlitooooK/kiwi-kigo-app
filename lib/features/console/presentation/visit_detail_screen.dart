import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_timeline.dart';
import '../../../shared/widgets/kigo_loader.dart';
import '../../../shared/widgets/kigo_error.dart';

/// Visit Detail Screen — Full visit info for console users.
class VisitDetailScreen extends ConsumerStatefulWidget {
  final String visitId;
  final Map<String, dynamic>? initialData;

  const VisitDetailScreen({
    super.key,
    required this.visitId,
    this.initialData,
  });

  @override
  ConsumerState<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends ConsumerState<VisitDetailScreen> {
  Map<String, dynamic>? _visitData;
  List<Map<String, dynamic>> _journeyEvents = [];
  bool _isLoading = true;
  bool _isActioning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      final data = await visitRepo.getVisitDetail(widget.visitId);
      final journey = await journeyRepo.getJourney(widget.visitId);

      if (mounted) {
        setState(() {
          _visitData = data;
          _journeyEvents = journey;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el detalle. Intenta de nuevo.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authorize() async {
    setState(() => _isActioning = true);

    try {
      final client = ref.read(supabaseProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final user = ref.read(currentUserProvider);

      await client.from('access_decisions').insert({
        'visit_id': widget.visitId,
        'decision': 'GRANTED',
        'decided_by': 'HOST',
        'decided_by_user_id': user?.id,
        'reason': 'Authorized from console',
      });

      await client
          .from('visits')
          .update({'status': 'ACTIVE', 'checked_in_at': DateTime.now().toIso8601String()})
          .eq('id', widget.visitId);

      await journeyRepo.logEvent(
        visitId: widget.visitId,
        eventType: 'HOST_APPROVED',
        payload: {'from': 'console', 'user_id': user?.id},
      );

      await journeyRepo.logEvent(
        visitId: widget.visitId,
        eventType: 'CHECKED_IN',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita autorizada correctamente'),
            backgroundColor: KigoTheme.green600,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo autorizar la visita. Intenta de nuevo. ($e)'),
            backgroundColor: KigoTheme.red500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text(
            'Rechazar visita',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: KigoTheme.slate900,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: KigoTheme.slate900),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(
                'Rechazar',
                style: TextStyle(color: KigoTheme.red500),
              ),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    setState(() => _isActioning = true);

    try {
      final client = ref.read(supabaseProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final user = ref.read(currentUserProvider);

      await client.from('access_decisions').insert({
        'visit_id': widget.visitId,
        'decision': 'DENIED',
        'decided_by': 'HOST',
        'decided_by_user_id': user?.id,
        'reason': reason.isNotEmpty ? reason : 'Rejected from console',
      });

      await client
          .from('visits')
          .update({'status': 'REJECTED'})
          .eq('id', widget.visitId);

      await journeyRepo.logEvent(
        visitId: widget.visitId,
        eventType: 'HOST_REJECTED',
        payload: {'from': 'console', 'reason': reason},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita rechazada'),
            backgroundColor: KigoTheme.yellow400,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo rechazar. Intenta de nuevo. ($e)'),
            backgroundColor: KigoTheme.red500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: KigoLoader(message: 'Cargando detalle'));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: KigoError(message: _error!, onRetry: _loadData),
      );
    }

    final visit = _visitData!;
    final visitor = visit['visitors'] as Map<String, dynamic>? ?? {};
    final host = visit['profiles'] as Map<String, dynamic>? ?? {};
    final trustEvals = visit['trust_evaluations'] as List<dynamic>? ?? [];
    final status = visit['status'] as String? ?? '';

    final firstName = visitor['first_name'] ?? '';
    final lastName = visitor['last_name'] ?? '';
    final company = visitor['company'] ?? '';
    final email = visitor['email'] ?? '';
    final phone = visitor['phone'] ?? '';
    final visitorType = visitor['visitor_type'] ?? '';
    final hostName = host['full_name'] ?? 'No asignado';
    final purpose = visit['purpose'] ?? '';
    final area = visit['area'] ?? '';
    final source = visit['source'] ?? '';

    // Trust score
    double? trustScore;
    if (trustEvals.isNotEmpty) {
      trustScore = (trustEvals.last['score'] as num?)?.toDouble();
    }

    final canAuthorize = ['PENDING', 'PRE_AUTHORIZED', 'IN_PROGRESS']
        .contains(status);

    return Scaffold(
      appBar: AppBar(
        title: Text('$firstName $lastName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                _StatusChip(status: status),
                const Spacer(),
                if (source.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KigoTheme.umbral100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.source_outlined, size: 14, color: KigoTheme.slate500),
                        const SizedBox(width: 4),
                        Text(
                          source,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KigoTheme.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Visitor info section
            const _SectionTitle(title: 'Visitante'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: KigoTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KigoTheme.umbral200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Nombre', value: '$firstName $lastName'),
                  if (company.isNotEmpty)
                    _InfoRow(label: 'Empresa', value: company),
                  if (email.isNotEmpty)
                    _InfoRow(label: 'Correo', value: email),
                  if (phone.isNotEmpty)
                    _InfoRow(label: 'Teléfono', value: phone),
                  if (visitorType.isNotEmpty)
                    _InfoRow(label: 'Tipo', value: visitorType),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Visit info section
            const _SectionTitle(title: 'Visita'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: KigoTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KigoTheme.umbral200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Anfitrión', value: hostName),
                  if (purpose.isNotEmpty)
                    _InfoRow(label: 'Motivo', value: purpose),
                  if (area.isNotEmpty)
                    _InfoRow(label: 'Área', value: area),
                  if (visit['scheduled_start'] != null)
                    _InfoRow(
                      label: 'Horario',
                      value: _formatSchedule(
                        visit['scheduled_start'],
                        visit['scheduled_end'],
                      ),
                    ),
                ],
              ),
            ),

            // Trust Score section
            if (trustScore != null) ...[
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Trust Score'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Score circle
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: trustScore / 100,
                            strokeWidth: 6,
                            backgroundColor: KigoTheme.umbral200,
                            color: _trustColor(trustScore),
                          ),
                          Center(
                            child: Text(
                              '${trustScore.toInt()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: KigoTheme.slate900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trustLabel(trustScore),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _trustColor(trustScore),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Calidad de registro y evidencia',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: KigoTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Evidence photos section
            if (_hasEvidence(visit)) ...[
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Evidencia'),
              const SizedBox(height: 12),
              _EvidenceSection(
                evidence: List<Map<String, dynamic>>.from(
                  visit['visit_evidence'] as List? ?? [],
                ),
                supabaseClient: ref.read(supabaseProvider),
              ),
            ],

            // Journey section
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Recorrido de visita'),
            const SizedBox(height: 12),
            if (_journeyEvents.isNotEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(16),
                child: JourneyTimeline(events: _journeyEvents),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Sin eventos registrados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
              ),

            // Actions
            if (canAuthorize) ...[
              const SizedBox(height: 32),
              const _SectionTitle(title: 'Acciones'),
              const SizedBox(height: 12),
              if (_isActioning)
                const KigoLoader(message: 'Procesando acción')
              else
                Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KigoTheme.greenGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: MaterialButton(
                          onPressed: _authorize,
                          height: 46,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: KigoTheme.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Autorizar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: KigoTheme.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _reject,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Rechazar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KigoTheme.red500,
                            side: const BorderSide(color: KigoTheme.red500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  bool _hasEvidence(Map<String, dynamic> visit) {
    final evidence = visit['visit_evidence'] as List?;
    return evidence != null && evidence.isNotEmpty;
  }

  String _formatSchedule(String? start, String? end) {
    if (start == null) return '';
    final format = DateFormat('HH:mm');
    final s = format.format(DateTime.parse(start).toLocal());
    if (end != null) {
      final e = format.format(DateTime.parse(end).toLocal());
      return '$s — $e';
    }
    return s;
  }

  Color _trustColor(double score) {
    if (score >= 85) return KigoTheme.green600;
    if (score >= 70) return KigoTheme.yellow400;
    return KigoTheme.red500;
  }

  String _trustLabel(double score) {
    if (score >= 85) return 'Excelente';
    if (score >= 70) return 'Aceptable';
    return 'Bajo';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: KigoTheme.slate900,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: KigoTheme.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBgColor();
    final textColor = _getTextColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color _getBgColor() {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green100;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
        return KigoTheme.sky50;
      case 'IN_PROGRESS':
        return KigoTheme.yellow50;
      case 'COMPLETED':
        return KigoTheme.umbral100;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red100;
      default:
        return KigoTheme.umbral100;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
        return KigoTheme.green600;
      case 'PENDING':
      case 'PRE_AUTHORIZED':
        return KigoTheme.sky900;
      case 'IN_PROGRESS':
        return KigoTheme.yellow400;
      case 'COMPLETED':
        return KigoTheme.slate500;
      case 'REJECTED':
      case 'CANCELLED':
        return KigoTheme.red500;
      default:
        return KigoTheme.slate500;
    }
  }

  String _getLabel() {
    switch (status) {
      case 'ACTIVE':
        return 'Activa';
      case 'CHECKED_IN':
        return 'Check-in';
      case 'PENDING':
        return 'Pendiente';
      case 'PRE_AUTHORIZED':
        return 'Pre-autorizada';
      case 'IN_PROGRESS':
        return 'En proceso';
      case 'COMPLETED':
        return 'Completada';
      case 'REJECTED':
        return 'Rechazada';
      case 'CANCELLED':
        return 'Cancelada';
      default:
        return status;
    }
  }
}

/// Evidence Section — Shows ID document and selfie photos using signed URLs.
///
/// UX ANALYSIS — Evidence Section
/// User: Admin/Host reviewing a visit
/// Goal: Quickly verify the visitor's identity documentation
/// Emotional state: Evaluative — needs clear, large images
///
/// Visual hierarchy:
/// 1. Evidence type label (ID Frente / Selfie)
/// 2. Image (dominant)
/// 3. Metadata (size, quality — subtle)
///
/// Semantic CTA: None (view-only)
/// Removals: No download button needed for MVP
class _EvidenceSection extends StatefulWidget {
  final List<Map<String, dynamic>> evidence;
  final dynamic supabaseClient;

  const _EvidenceSection({
    required this.evidence,
    required this.supabaseClient,
  });

  @override
  State<_EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends State<_EvidenceSection> {
  final Map<String, String?> _signedUrls = {};
  bool _isLoadingUrls = true;

  @override
  void initState() {
    super.initState();
    _loadSignedUrls();
  }

  Future<void> _loadSignedUrls() async {
    try {
      for (final item in widget.evidence) {
        final storagePath = item['storage_path'] as String?;
        final type = item['type'] as String?;
        if (storagePath == null || type == null) continue;

        // Determine bucket based on type
        final bucket = type == 'SELFIE' ? 'visitor-photos' : 'visit-evidence';

        final url = await widget.supabaseClient.storage
            .from(bucket)
            .createSignedUrl(storagePath, 3600); // 1 hour

        _signedUrls[storagePath] = url;
      }
    } catch (_) {
      // Silently fail — images just won't show
    } finally {
      if (mounted) setState(() => _isLoadingUrls = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUrls) {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: KigoTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KigoTheme.umbral200),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KigoTheme.kigo500,
            ),
          ),
        ),
      );
    }

    if (widget.evidence.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: KigoTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KigoTheme.umbral200),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Sin evidencia capturada',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray500,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KigoTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KigoTheme.umbral200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid of evidence items
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.evidence.map((item) {
              final type = item['type'] as String? ?? '';
              final storagePath = item['storage_path'] as String?;
              final url = storagePath != null ? _signedUrls[storagePath] : null;

              return _EvidenceCard(
                type: type,
                imageUrl: url,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final String type;
  final String? imageUrl;

  const _EvidenceCard({required this.type, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: KigoTheme.sky50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _typeLabel(type),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: KigoTheme.sky900,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Image
        GestureDetector(
          onTap: imageUrl != null
              ? () => _showFullImage(context, imageUrl!)
              : null,
          child: Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              color: KigoTheme.umbral100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KigoTheme.umbral200),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: KigoTheme.kigo500,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 24,
                              color: KigoTheme.gray400,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No disponible',
                              style: TextStyle(
                                fontSize: 11,
                                color: KigoTheme.gray400,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: KigoTheme.gray400,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sin imagen',
                          style: TextStyle(
                            fontSize: 11,
                            color: KigoTheme.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 300,
                    color: KigoTheme.umbral100,
                    child: const Center(
                      child: Text(
                        'No se pudo cargar la imagen',
                        style: TextStyle(color: KigoTheme.gray500),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KigoTheme.slate900.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ID_FRONT':
        return 'Identificación (frente)';
      case 'ID_BACK':
        return 'Identificación (reverso)';
      case 'SELFIE':
        return 'Fotografía';
      default:
        return type;
    }
  }
}
