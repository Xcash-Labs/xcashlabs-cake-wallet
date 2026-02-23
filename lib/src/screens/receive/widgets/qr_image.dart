import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;

class QrImage extends StatefulWidget {
  QrImage({
    required this.data,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.size,
    this.version,
    this.errorCorrectionLevel = qr.QrErrorCorrectLevel.H,
    this.embeddedImagePath,
  });

  final double? size;
  final Color foregroundColor;
  final Color backgroundColor;
  final String data;
  final int? version;
  final int errorCorrectionLevel;
  final String? embeddedImagePath;

  @override
  State<QrImage> createState() => _QrImageState();
}

class _QrImageState extends State<QrImage> {
  qr.QrImageView? qrImage = null;

  @override
  void initState() {
    super.initState();
    loadQr();
  }

  @override
  void didUpdateWidget(covariant QrImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data ||
        oldWidget.size != widget.size ||
        oldWidget.version != widget.version ||
        oldWidget.errorCorrectionLevel != widget.errorCorrectionLevel ||
        oldWidget.foregroundColor != widget.foregroundColor ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.embeddedImagePath != widget.embeddedImagePath) {
      setState(() {
        loadQr();
      });
    }
  }

  void loadQr() {
    final imagePath = widget.embeddedImagePath ?? 'assets/images/qr-cake.png';

    qrImage = qr.QrImageView(
      data: widget.data,
      errorCorrectionLevel: widget.errorCorrectionLevel,
      version: widget.version ?? qr.QrVersions.auto,
      size: widget.size,
      foregroundColor: widget.foregroundColor,
      backgroundColor: widget.backgroundColor,
      padding: const EdgeInsets.all(12.0),
      embeddedImage: imagePath.endsWith(".svg") ? null : AssetImage(imagePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.embeddedImagePath ?? 'assets/images/qr-cake.png';
    final isSvg = imagePath.endsWith('.svg');

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = constraints.biggest.shortestSide;
        final logoSize = qrSize * 0.25;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (qrImage != null) qrImage!,
            if (isSvg)
              SvgPicture.asset(
                imagePath,
                width: logoSize,
                height: logoSize,
              ),
          ],
        );
      },
    );
  }
}
