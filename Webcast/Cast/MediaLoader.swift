import GoogleCast

enum MediaLoader {
    // https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_media_information_builder
    static func request(for video: VideoCandidate) -> GCKMediaLoadRequestData {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(video.displayTitle, forKey: kGCKMetadataKeyTitle)
        metadata.setString(video.host, forKey: kGCKMetadataKeySubtitle)
        let media = GCKMediaInformationBuilder(contentURL: video.url)
        media.contentType = video.format.contentType
        media.metadata = metadata
        media.streamType = video.isLive == true ? .live : .buffered
        if let duration = video.duration { media.streamDuration = duration }
        if video.format == .hls {
            if video.segmentFormat == "ts" {
                media.hlsSegmentFormat = .TS
                media.hlsVideoSegmentFormat = .MPEG2_TS
            } else if video.segmentFormat == "fmp4" {
                media.hlsSegmentFormat = .FMP4
                media.hlsVideoSegmentFormat = .FMP4
            }
        }
        let request = GCKMediaLoadRequestDataBuilder()
        request.mediaInformation = media.build()
        request.autoplay = true
        return request.build()
    }
}
