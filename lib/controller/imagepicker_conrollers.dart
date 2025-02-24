import 'package:image_picker/image_picker.dart';
import 'package:new_todo/model/image_picker_model.dart';

class imagepickerController {
  final ImageModel _imageModel = ImageModel();
  Future<void> pickimage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _imageModel.imagePath = image.path;
    }
  }

  String? getImagePath() {
    return _imageModel.imagePath;
  }
}
