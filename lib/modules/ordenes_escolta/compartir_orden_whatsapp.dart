import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/whatsapp_pdf_android.dart';

class CompartirOrdenWhatsapp extends StatefulWidget {
  final Uint8List pdf;
  final String mensaje;
  final String nombreArchivo;
  final bool automatico;
  final Future<void> Function(Uint8List, String, String, Rect)? compartir;
  final Future<void> Function(Uint8List, String, String)? abrirDirecto;
  const CompartirOrdenWhatsapp({
    super.key,
    required this.pdf,
    required this.mensaje,
    required this.nombreArchivo,
    this.automatico = false,
    this.compartir,
    this.abrirDirecto,
  });

  @override
  State<CompartirOrdenWhatsapp> createState() => _CompartirOrdenWhatsappState();
}

class _CompartirOrdenWhatsappState extends State<CompartirOrdenWhatsapp> {
  bool _busy = false;
  String? _error;
  String? _estado;
  final _shareKey = GlobalKey();
  Animation<double>? _entrada;

  void _alEntrar(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entrada?.removeStatusListener(_alEntrar);
    _entrada = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _share();
    });
  }

  @override
  void dispose() {
    _entrada?.removeStatusListener(_alEntrar);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.automatico &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // iOS cannot present a share sheet while the route is being presented.
        final entrada = ModalRoute.of(context)?.animation;
        if (entrada != null && entrada.status != AnimationStatus.completed) {
          _entrada = entrada;
          entrada.addStatusListener(_alEntrar);
        } else {
          _share();
        }
      });
    }
  }

  Future<bool> _selector(Rect origin) async {
    if (widget.compartir != null) {
      await widget.compartir!(
        widget.pdf,
        widget.mensaje,
        widget.nombreArchivo,
        origin,
      );
      return true;
    }
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
    return result.status != ShareResultStatus.dismissed;
  }

  Future<void> _share({bool selector = false}) async {
    if (_busy) return;
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _error = null;
      _estado = null;
    });
    try {
      var preparado = true;
      if (!selector &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        try {
          await (widget.abrirDirecto ?? WhatsappPdfAndroid.abrir)(
            widget.pdf,
            widget.mensaje,
            widget.nombreArchivo,
          );
        } catch (_) {
          // Some installed variants cannot resolve the explicit WhatsApp intent.
          // The system chooser still receives exactly the same PDF and details.
          if (!mounted) return;
          preparado = await _selector(origin);
        }
      } else {
        preparado = await _selector(origin);
      }
      if (mounted) {
        setState(
          () => _estado = preparado
              ? 'PDF preparado. Seleccione el contacto y confirme el envío desde su cuenta de WhatsApp; la app no puede verificar su entrega.'
              : 'Compartir cancelado. Puede volver a intentarlo sin reenviar el correo.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo compartir el PDF. Reintente con «Compartir PDF y detalles»; no se volverá a enviar el correo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
      const SizedBox(height: 8),
      const Text(
        'Se usará la cuenta abierta en WhatsApp. Usted elige el contacto al compartir; no hay un destinatario fijo.',
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'En iPhone, el PDF ya va adjunto a la hoja de compartir. Elija WhatsApp y después el contacto.',
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: _shareKey,
        onPressed: _busy ? null : () => _share(),
        icon: const Icon(Icons.share_outlined),
        label: Text(
          _busy
              ? 'Abriendo…'
              : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? 'Abrir PDF en WhatsApp'
              : 'Compartir PDF y detalles',
        ),
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        TextButton(
          onPressed: _busy ? null : () => _share(selector: true),
          child: const Text('Compartir PDF y detalles'),
        ),
      if (kIsWeb) ...[
        const Text(
          'Si el navegador no permite compartir archivos, descargue el PDF y adjúntelo en WhatsApp.',
        ),
        TextButton.icon(
          onPressed: _busy ? null : _download,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Descargar PDF'),
        ),
      ],
      if (_estado != null) Text(_estado!),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
