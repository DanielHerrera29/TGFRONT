import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/contacto_escolta.dart';
import '../../services/whatsapp_pdf_android.dart';

class CompartirOrdenWhatsapp extends StatefulWidget {
  final Uint8List pdf;
  final String mensaje;
  final String nombreArchivo;
  final bool automatico;
  final Future<ContactoEscolta> Function()? cargarContacto;
  final Future<void> Function(Uint8List, String, String, Rect)? compartir;
  const CompartirOrdenWhatsapp({
    super.key,
    required this.pdf,
    required this.mensaje,
    required this.nombreArchivo,
    this.automatico = false,
    this.cargarContacto,
    this.compartir,
  });

  @override
  State<CompartirOrdenWhatsapp> createState() => _CompartirOrdenWhatsappState();
}

class _CompartirOrdenWhatsappState extends State<CompartirOrdenWhatsapp> {
  ContactoEscolta? _contacto;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _estado;
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacto =
          await (widget.cargarContacto?.call() ?? ContactoEscolta.cargar());
      chatWhatsapp(
        contacto.destino,
        widget.mensaje,
      ); // Validate configured recipient.
      if (!mounted) return;
      setState(() {
        _contacto = contacto;
        _loading = false;
      });
      if (widget.automatico &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _share();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'El correo conserva su estado. No se pudo cargar el destino de WhatsApp.';
        });
      }
    }
  }

  Future<void> _share() async {
    if (_busy || _contacto == null) return;
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.compartir != null) {
        await widget.compartir!(
          widget.pdf,
          widget.mensaje,
          widget.nombreArchivo,
          origin,
        );
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await WhatsappPdfAndroid.abrir(
          widget.pdf,
          widget.mensaje,
          widget.nombreArchivo,
        );
      } else {
        final result = await Share.shareXFiles(
          [
            XFile.fromData(
              widget.pdf,
              mimeType: 'application/pdf',
              name: widget.nombreArchivo,
            ),
          ],
          text: widget.mensaje,
          fileNameOverrides: [widget.nombreArchivo],
          sharePositionOrigin: origin,
        );
        if (result.status == ShareResultStatus.dismissed) {
          if (mounted) {
            setState(
              () => _estado =
                  'Compartir cancelado. Puede volver a intentarlo sin reenviar el correo.',
            );
          }
          return;
        }
      }
      if (mounted) {
        setState(
          () => _estado =
              'PDF preparado. Seleccione el destinatario y confirme el envío en WhatsApp; la app no puede verificar su entrega.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo abrir WhatsApp con el PDF. Compruebe que esté instalado y reintente sin reenviar el correo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chat() async {
    try {
      final opened = await launchUrl(
        chatWhatsapp(_contacto!.destino, widget.mensaje),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No disponible');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo abrir WhatsApp. Compruebe que esté disponible en este dispositivo.',
        );
      }
    }
  }

  Future<void> _download() async {
    try {
      await XFile.fromData(
        widget.pdf,
        mimeType: 'application/pdf',
        name: widget.nombreArchivo,
      ).saveTo(widget.nombreArchivo);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo descargar el PDF. Reintente la descarga.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('WhatsApp', style: Theme.of(context).textTheme.titleLarge),
      if (_loading) const LinearProgressIndicator(),
      if (_contacto != null) ...[
        const SizedBox(height: 8),
        Text('Destino: ${_contacto!.destino}'),
        const SizedBox(height: 8),
        const Text(
          'Se usará la cuenta abierta en WhatsApp. Seleccione este destinatario al compartir el PDF.',
        ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'En iPhone, el PDF ya va adjunto a la hoja de compartir. Elija WhatsApp y después el destinatario.',
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: _shareKey,
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_outlined),
          label: Text(
            _busy
                ? 'Abriendo…'
                : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? 'Abrir PDF en WhatsApp'
                : 'Compartir PDF y detalles',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _chat,
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Abrir chat con el mensaje'),
        ),
        if (kIsWeb) ...[
          const Text(
            'En WhatsApp Web debe adjuntar el PDF descargado. Abrir el chat solo prepara el texto.',
          ),
          TextButton.icon(
            onPressed: _busy ? null : _download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar PDF'),
          ),
        ],
      ],
      if (_estado != null) Text(_estado!),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (!_loading && _contacto == null)
        TextButton(onPressed: _load, child: const Text('Reintentar WhatsApp')),
    ],
  );
}
