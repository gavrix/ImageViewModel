//
//  ImageViewModel.swift
//  ImageViewModel
//
//  Created by Sergii Gavryliuk on 2016-03-24.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import UIKit
import ReactiveCocoa
import Result


protocol ImageProvider {
    
    func image(url url:NSURL, size:CGSize) -> SignalProducer<UIImage, NoError>
    func image(image: UIImage, size: CGSize) -> SignalProducer<UIImage, NoError>
}

public enum ImageDescriptor {
    case Image(UIImage)
    case URL(NSURL)
}

extension ImageDescriptor {
    func resizedImage(imageProvider: ImageProvider, size: CGSize) -> SignalProducer<UIImage, NoError> {
        switch self {
        case .Image(let image):
            return imageProvider.image(image, size: size)
        case .URL(let url):
            return imageProvider.image(url: url, size: size)

        }
    }
}

public class ImageViewModel {
    
    public let imageViewSize = MutableProperty(CGSize.zero)
    public let image = MutableProperty<ImageDescriptor?>(nil)
    
    public let resultImage: AnyProperty<UIImage?>
    public let imageTransitionSignal: Signal<Void, NoError>
    
    init(imageProvider: ImageProvider, defaultImage: UIImage? = nil) {
        
        let (imgTransitionSignal, sink) = Signal<Void, NoError>.pipe()
                
        let defaultImageSignal = (defaultImage != nil) ? self.imageViewSize.producer
            .skipRepeats()
            .flatMap(.Latest) {
                size -> SignalProducer<UIImage?, NoError> in

                if size != .zero {
                    return imageProvider.image(defaultImage!, size: size).map { .Some($0) }
                } else {
                    return SignalProducer(value: nil)
                }
            } : SignalProducer(value: nil)
        
        let actualImageSignals = combineLatest(self.image.producer, self.imageViewSize.producer.skipRepeats())
            .map {
                (image, size) -> SignalProducer<UIImage?, NoError> in
                if let image = image where size != .zero  {
                    return image.resizedImage(imageProvider, size: size).map { .Some($0) }
                } else {
                    return SignalProducer.never
                }
        }
        
        let compoundImageSignal = actualImageSignals.flatMap(.Latest) {
            signal -> SignalProducer<UIImage?, NoError> in
            
            var transitionAction: (() -> ())? = nil
            
            let nonFailingSignal = signal
                .on { _ in transitionAction?() }
            
            return defaultImageSignal
                .on { _ in transitionAction = { sink.sendNext() } }
                .takeUntilReplacement(nonFailingSignal)
            
        }
        
        self.imageTransitionSignal = imgTransitionSignal
        resultImage = AnyProperty(initialValue: nil, producer:compoundImageSignal)
    }
}


