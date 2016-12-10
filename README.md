# ImageViewModel

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Cocoapods](https://img.shields.io/cocoapods/v/ImageViewModel.svg)](http://cocoadocs.org/docsets/ImageViewModel/0.0.2/) 
[![Build Status](https://travis-ci.org/gavrix/ImageViewModel.svg?branch=0.0.3)](https://travis-ci.org/gavrix/ImageViewModel)

RAC-based µ-ViewModel for managing images represented as URLs. Simplifies routine tasks of laoding images from the nethwork, caching, resizing, post-processing. Written purely in swift.

## Usage

`ImageViewModel` class abstracts away all the logic around preparing the `UIImage` instance, uses dependency conforming to `ImageProvider` protocol for actual image loading and processing.

1. Create suitable imageProvider by implementing ImageProvider protocol:
  ```
  struct SimpleImageProvider: ImageProvider {
    func image(image: UIImage, size: CGSize) -> SignalProducer<UIImage, NoError> {
        return resizeImage(size, image: image)
    }
    
    func image(url url: NSURL, size: CGSize) -> SignalProducer<UIImage, NoError> {
        return self.cachedDownloadSignal(url).flatMap(.Merge) { image in
            return self.cachedResizedImage(image, size:size, key: "\(url)_\(size)")
        }
    }
    
    ... // implement `cachedDownloadSignal` `cachedResizedImage` `resizeImage`
  }
  ```

2. Create `ImageViewModel` instance with given `ImageProvider` and optionally default image, used while actual image is being prepared.
  ```
  self.imageViewModel = ImageViewModel(imageProvider: globalImageProvider)
  ```

3. Connect `ImageViewModel` instance to UI: 
  - set the ImageViewModel's `imageViewSize` property, most of the time inside `layoutSubviews` of the `UIView` or in `viewDidLayoutSubviews` of the `UIViewController`:
    ```
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageViewModel.imageViewSize.value = self.userpicImageView.frame.size
    }
    ```
    
  - observe `resultImage` property from the `ImageViewModel`:
    ```
    self.imageViewModel.resultImage.producer.startWithNext {
            [unowned self] image in
            self.userpicImageView.image = image
        }
    ```
  
  - optionally, observe `imageTransitionSignal` signal from the `ImageViewModel` that triggers when image was delivered asynchronously:
    ```
     self.viewModel.userpicViewModel.imageTransitionSignal.observeNext {
            [unowned self] in
            let transition = CATransition()
            transition.type = kCATransitionFade
            self.userpicImageView?.layer.addAnimation(transition, forKey: nil)
        }
    ```

4. Set `ImageViewModel`'s `image` property to image URL (or local image as `UIImage` instance):
  ```
  self.imageViewModel.image.value = .URL(modelObject.imageURL)
  ```

That's it. Everytime `UIImageView` size changes or new value is set to `image` property, `ImageViewModel` will attempt to prepare image through `ImageProvider` used and if image is being delivered asynchronously, it will propagate default image first, then prepared image as well as trigger `imageTransitionSignal` accordingly.

## Installation

### Direct checkout

Checkout this repository, copy `ImageViewModel` folder into your project's 3rd party dependencies folder. Then drag `ImageViewModel.xcodeproj` into your master project. Don't forget to add `ImageViewModel` in in your master project's Target dependencies build phase.

### Carthage

In your Cartfile add the following line:

```
git "https://github.com/gavrix/ImageViewModel.git" "0.0.2"
```

### Cocoapods

`ImageViewModel` also available via cocoapods. Add following line in your podfile:

```
pod 'ImageViewModel', '0.0.2'
```

## Example project.

Refer to example project in a [collection](https://github.com/gavrix/ViewModelsSamples) of samples for other ViewModel based µ-frameworks [here](https://github.com/gavrix/ViewModelsSamples/blob/master/ImageViewModelExample/README.md).


## Credits

`ImageViewModel` created by Sergey Gavrilyuk [@octogavrix](http://twitter.com/octogavrix).


## License

`ImageViewModel` is distributed under MIT license. See LICENSE for more info.
