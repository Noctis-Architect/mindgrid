#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Apply the caption-less frame computed in WM_NCCALCSIZE.
  SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "mindgrid/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND hwnd = GetHandle();
        const std::string& method = call.method_name();
        if (hwnd == nullptr) {
          result->Error("no_window", "Window is not available");
          return;
        }
        if (method == "startDrag") {
          result->Success();
          ReleaseCapture();
          PostMessage(hwnd, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
        } else if (method == "startResize") {
          WPARAM edge = WMSZ_BOTTOMRIGHT;
          if (const auto* name = std::get_if<std::string>(call.arguments())) {
            if (*name == "top") edge = WMSZ_TOP;
            else if (*name == "bottom") edge = WMSZ_BOTTOM;
            else if (*name == "left") edge = WMSZ_LEFT;
            else if (*name == "right") edge = WMSZ_RIGHT;
            else if (*name == "topLeft") edge = WMSZ_TOPLEFT;
            else if (*name == "topRight") edge = WMSZ_TOPRIGHT;
            else if (*name == "bottomLeft") edge = WMSZ_BOTTOMLEFT;
          }
          result->Success();
          ReleaseCapture();
          PostMessage(hwnd, WM_SYSCOMMAND, SC_SIZE | edge, 0);
        } else if (method == "minimize") {
          ShowWindow(hwnd, SW_MINIMIZE);
          result->Success();
        } else if (method == "toggleMaximize") {
          ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
        } else if (method == "isMaximized") {
          result->Success(flutter::EncodableValue(IsZoomed(hwnd) != 0));
        } else if (method == "close") {
          result->Success();
          PostMessage(hwnd, WM_CLOSE, 0, 0);
        } else {
          result->NotImplemented();
        }
      });

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
  window_channel_ = nullptr;
  if (flutter_controller_) {
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
