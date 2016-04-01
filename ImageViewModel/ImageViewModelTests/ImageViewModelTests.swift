//
//  ImageViewModelTests.swift
//  ImageViewModelTests
//
//  Created by Sergii Gavryliuk on 2016-03-24.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import XCTest
import ReactiveCocoa
import Result

@testable import ImageViewModel

class ImageViewModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitialState() {
        let imageProvider = TestImageProvider(
            downloadFunc: {_, size in return .empty },
            resizeFunc: {_,size in return .empty }
        )
        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)

        XCTAssertEqual(imageViewModel.resultImage.value, nil, "initial value of resultImage should be nil")
        XCTAssertEqual(imageViewModel.imageViewSize.value, CGSize.zero, "initial value of imageViewSize should be zero")

    }
    
    func testDefaultImage() {
        
        var imageAskedToResize: UIImage? = nil
        var resizeCount = 0
        
        let resizedDefaultImage = UIImage()
        
        let imageProvider = TestImageProvider(
            downloadFunc: {_,_ in return .empty },
            resizeFunc: { image, size in
                imageAskedToResize = image
                resizeCount += 1
                return SignalProducer(value: resizedDefaultImage)
            }
        )
        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)


        XCTAssertEqual(imageViewModel.resultImage.value, nil, "Should be nil until defualtImage or non-zero imageSize provided")
        
        let imageSize = CGSize(width: 10, height: 10)
        imageViewModel.imageViewSize.value = imageSize
        
        XCTAssertEqual(imageAskedToResize, defaultImage, "Should have requested the default image")
        
        XCTAssertEqual(imageViewModel.resultImage.value, resizedDefaultImage, "resized image should be equal to provided by image provider")
    }
    
    func testImageProviderParamsConsistency() {
        
        var resizedImageSizeRequested = CGSize.zero
        var downloadedImageSize = CGSize.zero
        var downloadURLRequested = NSURL()
        
        let imageProvider = TestImageProvider(
            downloadFunc: {url,size in
                downloadedImageSize = size
                downloadURLRequested = url
                return SignalProducer(value: UIImage())
            },
            resizeFunc: { image, size in
                resizedImageSizeRequested = size
                return SignalProducer(value: UIImage())
            }
        )
        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)
        
        let imageSize = CGSize(width: 10, height: 10)
        imageViewModel.imageViewSize.value = imageSize

        XCTAssertEqual(resizedImageSizeRequested, imageSize, "ImageSize requested should be equal to value set in `imageViewSize`")
        resizedImageSizeRequested = .zero
        
        let url = NSURL(string: "http://google.com/image.png")!
        imageViewModel.image.value = .URL(url)

        XCTAssertEqual(downloadedImageSize, imageSize, "Should have requested downloaded image once")
        XCTAssertEqual(downloadURLRequested, url, "Should have requested downloaded image once")
        
        let url2 = NSURL(string: "http://google.com/image.png")!
        let imageSize2 = CGSize(width: 10, height: 10)
        
        imageViewModel.image.value = .URL(url2)
        XCTAssertEqual(downloadURLRequested, url2, "Should have requested downloaded image once")
        
        imageViewModel.imageViewSize.value = imageSize2
        XCTAssertEqual(downloadedImageSize, imageSize2, "Should have requested downloaded image once")
    }
    
    
    func testSyncAsyncDownload() {
        
        var defaultResizeCount = 0
        var downloadCount = 0
        
        let (downloadSignal, downloadSink) = SignalProducer<UIImage, NoError>.buffer(1)
        
        let imageProvider = TestImageProvider(
            downloadFunc: {_,size in
                downloadCount += 1
                return downloadSignal
            },
            resizeFunc: { image, size in
                defaultResizeCount += 1
                return SignalProducer(value: UIImage())
            }
        )

        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)
        
        let imageSize = CGSize(width: 10, height: 10)
        imageViewModel.imageViewSize.value = imageSize
        
        XCTAssertEqual(defaultResizeCount, 1, "Should have requested resized image once")
        defaultResizeCount = 0

        imageViewModel.image.value = .URL(NSURL(string: "http://google.com/image.png")!)
        
        XCTAssertEqual(defaultResizeCount, 1, "Should have requested resized image once")
        defaultResizeCount = 0
        
        downloadSink.sendNext(UIImage())
        downloadSink.sendCompleted()

        XCTAssertEqual(downloadCount, 1, "Should have requested download image once")
        downloadCount = 0
        
        imageViewModel.image.value = .URL(NSURL(string: "http://google.com/image2.png")!)
        
        XCTAssertEqual(defaultResizeCount, 0, "Should NOT have requested resized image")
        defaultResizeCount = 0

        XCTAssertEqual(downloadCount, 1, "Should have requested download image once")
        downloadCount = 0
                
    }
    
    func testTransitionSignal() {
        let (downloadSignal, downloadSink) = SignalProducer<UIImage, NoError>.buffer(1)
        
        let imageProvider = TestImageProvider(
            downloadFunc: {_,size in
                return downloadSignal
            },
            resizeFunc: { image, size in
                return SignalProducer(value: UIImage())
            }
        )
        
        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)
        
        var transitionSignalRecevied = false
        imageViewModel.imageTransitionSignal.observeNext() {
            transitionSignalRecevied = true
        }

        imageViewModel.imageViewSize.value = CGSize(width: 10, height: 10)
        
        XCTAssertEqual(transitionSignalRecevied, false, "Should not send transition for default image");
        transitionSignalRecevied = false
        
        imageViewModel.image.value = .URL(NSURL(string: "http://google.com/image.png")!)

        downloadSink.sendNext(UIImage())
        downloadSink.sendCompleted()

        XCTAssertEqual(transitionSignalRecevied, true, "Should send transition when downloaded image is delivered asynchronously");
        transitionSignalRecevied = false

        imageViewModel.image.value = .URL(NSURL(string: "http://google.com/image2.png")!)

        XCTAssertEqual(transitionSignalRecevied, false, "Should NOT send transition when downloaded image is delivered synchronously");
        transitionSignalRecevied = false
        
    }
    
    func testResultImage() {
        
        let (downloadSignal, downloadSink) = SignalProducer<UIImage, NoError>.buffer(1)
        let (defaultResizedSignal, defaultResizedSink) = SignalProducer<UIImage, NoError>.buffer(1)
        
        let imageProvider = TestImageProvider(
            downloadFunc: {_,size in
                return downloadSignal
            },
            resizeFunc: { image, size in
                return defaultResizedSignal
            }
        )
        
        let defaultImage = UIImage()
        let imageViewModel = ImageViewModel(imageProvider: imageProvider, defaultImage: defaultImage)

        XCTAssertEqual(imageViewModel.resultImage.value, nil, "Resulting image should be nil before valid imageViewSize is provided");
        
        imageViewModel.imageViewSize.value = CGSize(width: 10, height: 10)
        
        XCTAssertEqual(imageViewModel.resultImage.value, nil, "Resulting image should remain nil before download or resized image delivered");
        
        let defaultResizedImage = UIImage()
        defaultResizedSink.sendNext(defaultResizedImage)
        defaultResizedSink.sendCompleted()

        XCTAssertEqual(imageViewModel.resultImage.value, defaultResizedImage, "Resulting image should be the one provided by imageProvider");

        imageViewModel.image.value = .URL(NSURL(string: "http://google.com/image.png")!)
        
        XCTAssertEqual(imageViewModel.resultImage.value, defaultResizedImage, "Resulting image should remain to be resized default before download delivers");
        
        let downloadedImage = UIImage()
        downloadSink.sendNext(downloadedImage)
        downloadSink.sendCompleted()

        XCTAssertEqual(imageViewModel.resultImage.value, downloadedImage, "Resulting image should be the one provided by imageProvider");
        
    }
    
}


class TestImageProvider: ImageProvider {

    var imageDownloadFunc: (NSURL, CGSize) -> SignalProducer<UIImage, NoError>;
    var imageResizeFunc: (UIImage, CGSize) -> SignalProducer<UIImage, NoError>;
    
    init(downloadFunc: (NSURL, CGSize) -> SignalProducer<UIImage, NoError>,
        resizeFunc: (UIImage, CGSize) -> SignalProducer<UIImage, NoError>) {
            self.imageDownloadFunc = downloadFunc;
            self.imageResizeFunc = resizeFunc;
    }

    func image(url url:NSURL, size:CGSize) -> SignalProducer<UIImage, NoError> {
        return self.imageDownloadFunc(url, size)
    }

    func image(image: UIImage, size: CGSize) -> SignalProducer<UIImage, NoError> {
        return self.imageResizeFunc(image, size)
    }


}


extension Signal {

    func producer() -> SignalProducer<Value, Error>{
        return SignalProducer() {
            sink, _ in
            self.observe(sink)
        }
    }
}
