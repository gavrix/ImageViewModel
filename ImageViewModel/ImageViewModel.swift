//
//  ImageViewModel.swift
//  ImageViewModel
//
//  Created by Sergii Gavryliuk on 2016-03-24.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import UIKit
import ReactiveSwift
import Result


public protocol ImageProvider {
    
    func image(url:URL, size:CGSize) -> SignalProducer<UIImage, NoError>
    func image(_ image: UIImage, size: CGSize) -> SignalProducer<UIImage, NoError>
}

public enum ImageDescriptor {
    case image(UIImage)
    case url(Foundation.URL)
}

extension ImageDescriptor {
    func resizedImage(_ imageProvider: ImageProvider, size: CGSize) -> SignalProducer<UIImage, NoError> {
        switch self {
        case .image(let image):
            return imageProvider.image(image, size: size)
        case .url(let url):
            return imageProvider.image(url: url, size: size)

        }
    }
}

open class ImageViewModel {
    
    open let imageViewSize = MutableProperty(CGSize.zero)
    open let image = MutableProperty<ImageDescriptor?>(nil)
    
    open let resultImage: Property<UIImage?>
    open let imageTransitionSignal: Signal<Void, NoError>
    
    public init(imageProvider: ImageProvider, defaultImage: UIImage? = nil) {
		
        let (imgTransitionSignal, sink) = Signal<Void, NoError>.pipe()
		let imaageSizeSignal = self.imageViewSize.producer.skipRepeats()
		
        let defaultImageSignal = (defaultImage != nil) ? imaageSizeSignal
            .flatMap(.latest) {
                size -> SignalProducer<UIImage?, NoError> in

                if size != .zero {
                    return imageProvider.image(defaultImage!, size: size).map { .some($0) }
                } else {
                    return SignalProducer(value: nil)
                }
            } : SignalProducer(value: nil)
		
		let actualImageSignals = self.image.producer.map {
			image -> SignalProducer<UIImage?, NoError> in
			
			if let image = image {
				return imaageSizeSignal.flatMap(.latest) { size -> SignalProducer<UIImage?, NoError> in
					if size != .zero  {
						return image.resizedImage(imageProvider, size: size).map { .some($0) }
					} else {
						return .never
					}
				}
			} else {
				return .never
			}
		}
		
        let compoundImageSignal = actualImageSignals.flatMap(.latest) {
            signal -> SignalProducer<UIImage?, NoError> in
            
            var transitionAction: (() -> ())? = nil
            
            let nonFailingSignal = signal
                .on { _ in transitionAction?() }
            
            return defaultImageSignal
				.on { _ in transitionAction = { sink.send(value: ()) } }
                .take(untilReplacement: nonFailingSignal)
            
        }
        
        self.imageTransitionSignal = imgTransitionSignal
        resultImage = Property(initial: nil, then: compoundImageSignal)
    }
}


