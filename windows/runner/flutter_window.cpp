#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Control.h>
#include <thread>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool PauseActiveMediaSession() {
  using namespace winrt::Windows::Media::Control;
  const auto manager =
      GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
  const auto session = manager.GetCurrentSession();
  if (!session) return false;
  const auto playback = session.GetPlaybackInfo();
  if (playback.PlaybackStatus() !=
      GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) {
    return false;
  }
  return session.TryPauseAsync().get();
}

bool ResumeActiveMediaSession() {
  using namespace winrt::Windows::Media::Control;
  const auto manager =
      GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
  const auto session = manager.GetCurrentSession();
  if (!session) return false;
  return session.TryPlayAsync().get();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  media_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "straight/media_control",
          &flutter::StandardMethodCodec::GetInstance());
  media_control_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "pauseIfPlaying") {
          std::thread([this, result = std::move(result)]() mutable {
            try {
              winrt::init_apartment(winrt::apartment_type::multi_threaded);
              const bool paused = PauseActiveMediaSession();
              media_paused_by_straight_.store(paused);
              result->Success(flutter::EncodableValue(paused));
            } catch (const std::exception& error) {
              result->Error("media_control_error", error.what());
            }
          }).detach();
          return;
        }
        if (call.method_name() == "resumeIfPausedByStraight") {
          std::thread([this, result = std::move(result)]() mutable {
            try {
              winrt::init_apartment(winrt::apartment_type::multi_threaded);
              if (media_paused_by_straight_.exchange(false)) {
                ResumeActiveMediaSession();
              }
              result->Success();
            } catch (const std::exception& error) {
              result->Error("media_control_error", error.what());
            }
          }).detach();
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  Show();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    media_control_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
