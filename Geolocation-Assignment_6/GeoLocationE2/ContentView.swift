import SwiftUI
import MapKit

struct ContentView: View {
    @ObservedObject var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var cameraPosition: MapCameraPosition = .region(.userRegion)
    @State private var mapSelection: MKMapItem?
    @State private var showDetails = false
    @State private var getDirections = false
    @State private var routeDisplaying = false
    @State private var route: MKRoute?
    @State private var routeDestination: MKMapItem?
    @State private var showingSearchResults = false

    var body: some View {
        Group {
            if locationManager.userLocation == nil {
                LocationRequestView()
            } else {
                VStack {
                    HStack {
                        TextField("Search for a location", text: $searchText, onCommit: {
                            Task { await searchPlaces() }
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Button(action: {
                            Task { await searchPlaces() }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .padding()
                        }
                        
                        if showingSearchResults {
                            Button(action: {
                                closeSearch()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .padding()
                            }
                        }
                    }
                    
                    Map(position: $cameraPosition, selection: $mapSelection) {
                        Annotation("My Location", coordinate: .userLocation) {
                            ZStack {
                                Circle()
                                    .frame(width: 170, height: 170)
                                    .foregroundStyle(.green.opacity(0.23))
                                Circle()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                Circle()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        ForEach(searchResults, id: \.self) { item in
                            let placemark = item.placemark
                            Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                        }
                        
                        if let route {
                            MapPolyline(route.polyline)
                                .stroke(.red, lineWidth: 6)
                        }
                    }
                    
                    if showingSearchResults {
                        List(searchResults, id: \.self) { item in
                            Button(action: {
                                mapSelection = item
                                showDetails = true
                                fetchRoute()
                            }) {
                                VStack(alignment: .leading) {
                                    Text(item.placemark.name ?? "")
                                        .font(.headline)
                                    Text(item.placemark.title ?? "")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
        }
    }
    
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .userRegion
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
            showingSearchResults = true
        } catch {
            print("Search failed: \(error.localizedDescription)")
        }
    }
    
    func fetchRoute() {
        if let mapSelection {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: .init(coordinate: .userLocation))
            request.destination = mapSelection
            
            Task {
                let result = try? await MKDirections(request: request).calculate()
                route = result?.routes.first
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                    
                    if let rect = route?.polyline.boundingMapRect, routeDisplaying {
                        cameraPosition = .rect(rect)
                    }
                }
            }
        }
    }
    
    func closeSearch() {
        searchText = ""
        searchResults = []
        showingSearchResults = false
        cameraPosition = .region(.userRegion)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// User Location Extensions
extension CLLocationCoordinate2D {
    static let userLocation = CLLocationCoordinate2D(latitude: 43.776035, longitude: -79.257713)
}

extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        return .init(center: .userLocation, latitudinalMeters: 10000, longitudinalMeters: 10000)
    }
}
