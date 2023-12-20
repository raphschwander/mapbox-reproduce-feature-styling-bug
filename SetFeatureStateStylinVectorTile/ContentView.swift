//
//  ContentView.swift
//  MapboxSwiftUI2
//
//  Created by Raphael Neuenschwander on 19.12.2023.
//

import SwiftUI
import Combine
import MapboxMaps

struct ContentView2: View {

    var body: some View {
        VStack {
            MapBoxView2()
        }
    }
}

#Preview {
    ContentView2()
}

struct MapBoxView2: UIViewRepresentable {

    func makeUIView(context: Context) -> MapView {

        let mapView = MapView(frame: CGRect.zero,
                              mapInitOptions: .init(styleURI: .satellite))
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        try! mapView.mapboxMap.setProjection(StyleProjection(name: .globe))
        mapView.mapboxMap.onStyleLoaded.observeNext { _ in
            try! mapView.mapboxMap.setAtmosphere(Atmosphere())
        }.store(in: &context.coordinator.cancellables)

        mapView.mapboxMap.onMapLoaded.observeNext { _ in
            self.addGeoJSONSource(to: mapView)
            self.addLayer(to: mapView)
        }.store(in: &context.coordinator.cancellables)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapAction(_:)))
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ uiView: MapView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject  {
        var parent: MapBoxView2

        var cancellables = Set<AnyCancellable>()

        init(_ parent: MapBoxView2) {
            self.parent = parent
        }

        @MainActor @objc func tapAction(_ sender: UITapGestureRecognizer) {
            let mapView = sender.view as! MapView
            let tapPoint = sender.location(in: mapView)

            mapView.mapboxMap.queryRenderedFeatures(
                with: tapPoint,
                options: RenderedQueryOptions(layerIds: ["fill-layer"], filter: nil)) { [weak self] result in
                switch result {
                case .success(let queriedfeatures):
                    if let firstFeature = queriedfeatures.first?.queriedFeature.feature, let properties = firstFeature.properties, let id = firstFeature.identifier?.rawValue as? String  {
                        mapView.mapboxMap.setFeatureState(sourceId: "countries", featureId: id, state: ["isSelected": true]) { setResult in
                            mapView.mapboxMap.getFeatureState(sourceId: "countries", featureId: id) { getResult in
                            }
                        }
                    }
                case .failure(let error):
                    print("failure")
                }
            }
        }
    }
}


extension MapBoxView2 {
    private func addGeoJSONSource(to mapView: MapView) {
        // Create the source for country polygons using the Mapbox Countries tileset
        // The polygons contain an ISO 3166 alpha-3 code which can be used to for joining the data
        // https://docs.mapbox.com/vector-tiles/reference/mapbox-countries-v1
        var source = VectorSource(id: "countries")
        source.url = "mapbox://mapbox.country-boundaries-v1"
        source.promoteId = .string("iso_3166_1")
        try! mapView.mapboxMap.addSource(source)

    }

    private func colorExpression(normal: String, selected: String) -> Expression {
        Exp(.switchCase) {
            Exp(.boolean) {
                Exp(.featureState) { "isSelected" }
                false
            }
            selected
            normal
        }
    }

    private func addLayer(to mapView: MapView) {
        var layer = FillLayer(id: "fill-layer", source: "countries")
        layer.sourceLayer = "country_boundaries"
        layer.fillColor = .expression(colorExpression(normal: "#b30000", selected: "#41e827"))
        layer.fillOpacity = .constant(0.7)
        layer.fillOutlineColor = .constant(.init(.red))
        try! mapView.mapboxMap.addLayer(layer)
    }
}
