import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminHotelImagePicker extends StatelessWidget {
  final XFile? pickedImage;
  final String? imageUrl;
  final VoidCallback onPick;

  const AdminHotelImagePicker({
    super.key,
    this.pickedImage,
    this.imageUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.grey[200],
                child:
                    pickedImage != null
                        ? Image.file(File(pickedImage!.path), fit: BoxFit.cover)
                        : (imageUrl != null && imageUrl!.isNotEmpty)
                        ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(Icons.broken_image),
                        )
                        : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
