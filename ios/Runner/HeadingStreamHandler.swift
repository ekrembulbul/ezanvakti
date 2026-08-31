import CoreLocation
import Flutter
import Foundation

/// Cihazın pusula yönünü Flutter'a akıtır.
///
/// Gerçek kuzey (`trueHeading`) tercih edilir; kıble açısı coğrafi kuzeye
/// göre hesaplandığı için manyetik kuzey kullanmak sapma kadar hata verirdi.
/// Cihaz gerçek kuzeyi bilmiyorsa (konum yok/izin yok) manyetik kuzeye
/// düşülür ve doğruluk değeri arayüzde kalibrasyon uyarısını tetikler.
class HeadingStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  static let channelName = "com.ekrembulbul.ezanvakti/heading"

  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    // 1°'den küçük değişimler ok'u titretiyor; okunabilirlik için filtre.
    manager.headingFilter = 1
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    channel.setStreamHandler(HeadingStreamHandler())
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(
        code: "heading_unavailable",
        message: "Bu cihazda pusula yok",
        details: nil)
    }
    sink = events
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard let sink else { return }
    // trueHeading geçersizken negatif gelir; o durumda manyetik kuzey
    // kullanılır ve doğruluk zaten uyarı eşiğinin üstündedir.
    let degrees = newHeading.trueHeading >= 0
      ? newHeading.trueHeading
      : newHeading.magneticHeading
    sink([
      "degrees": degrees,
      "accuracy": newHeading.headingAccuracy,
    ])
  }

  /// Sistem kalibrasyon çarkını göstersin: kullanıcı cihazı sekiz çizerek
  /// düzeltebilsin.
  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    true
  }
}
