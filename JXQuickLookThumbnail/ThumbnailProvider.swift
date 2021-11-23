//
//  ThumbnailProvider.swift
//  JXQuickLookThumbnail
//
//  Created by 黄俊亮 on 2021-11-17.
//

import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        if let img = try? JXL.parse(data: Data(contentsOf: request.fileURL)) {
            let contextMaxSize = request.maximumSize;
            let contextMinSize = request.minimumSize;
            let imgSize = img.size
            let ratio = min(contextMaxSize.width / imgSize.width, contextMaxSize.height / imgSize.height)
            // Preserve aspect ratio
            let contextSize = CGSize(width: max(contextMinSize.width, (imgSize.width * ratio).rounded(.down)), height: max(contextMinSize.height, (imgSize.height * ratio).rounded(.down)))
            let reply = QLThumbnailReply(contextSize: contextSize, currentContextDrawing: { () -> Bool in
                // Draw the thumbnail here.
                img.draw(in: CGRect(origin: .zero, size: contextSize))
                // Return true if the thumbnail was successfully drawn inside this block.
                return true
            });
            handler(reply, nil);
        } else {
            handler(nil, JXLError.cannotDecode);
        }
    }
}
