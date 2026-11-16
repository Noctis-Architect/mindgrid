#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <glib.h>

#include "flutter/generated_plugin_registrant.h"

static GdkPixbuf* load_app_icon() {
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path == nullptr) {
    return nullptr;
  }
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_path =
      g_build_filename(exe_dir, "data", "resources", "app_icon.png", nullptr);
  g_autoptr(GError) error = nullptr;
  return gdk_pixbuf_new_from_file(icon_path, &error);
}

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Current pointer position in root coordinates.
static void pointer_root_position(GtkWindow* window, gint* x, gint* y) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = gdk_seat_get_pointer(seat);
  gdk_device_get_position(pointer, nullptr, x, y);
}

// Finds the widget inside the Flutter view that receives pointer events.
static GtkWidget* find_event_box(GtkWidget* widget) {
  if (GTK_IS_EVENT_BOX(widget)) {
    return widget;
  }
  if (!GTK_IS_CONTAINER(widget)) {
    return nullptr;
  }
  GtkWidget* found = nullptr;
  GList* children = gtk_container_get_children(GTK_CONTAINER(widget));
  for (GList* l = children; l != nullptr && found == nullptr; l = l->next) {
    found = find_event_box(GTK_WIDGET(l->data));
  }
  g_list_free(children);
  return found;
}

// A window-manager move/resize swallows the button release, which would
// leave Flutter believing the button is still held (and eat the next click).
// Deliver the release ourselves before handing the pointer over.
static void release_flutter_pointer(GtkWindow* window) {
  GtkWidget* view =
      GTK_WIDGET(g_object_get_data(G_OBJECT(window), "mindgrid-fl-view"));
  if (view == nullptr) {
    return;
  }
  GtkWidget* target = find_event_box(view);
  if (target == nullptr || gtk_widget_get_window(target) == nullptr) {
    return;
  }
  GdkDisplay* display = gtk_widget_get_display(target);
  GdkDevice* pointer =
      gdk_seat_get_pointer(gdk_display_get_default_seat(display));
  gint root_x = 0, root_y = 0, x = 0, y = 0;
  gdk_device_get_position(pointer, nullptr, &root_x, &root_y);
  gdk_window_get_device_position(gtk_widget_get_window(target), pointer, &x,
                                 &y, nullptr);

  GdkEvent* event = gdk_event_new(GDK_BUTTON_RELEASE);
  event->button.window =
      GDK_WINDOW(g_object_ref(gtk_widget_get_window(target)));
  event->button.send_event = TRUE;
  event->button.time = gtk_get_current_event_time();
  event->button.x = x;
  event->button.y = y;
  event->button.x_root = root_x;
  event->button.y_root = root_y;
  event->button.button = 1;
  gdk_event_set_device(event, pointer);
  gboolean handled = FALSE;
  g_signal_emit_by_name(target, "button-release-event", event, &handled);
  gdk_event_free(event);
}

static GdkWindowEdge edge_from_name(const gchar* name) {
  if (g_strcmp0(name, "top") == 0) return GDK_WINDOW_EDGE_NORTH;
  if (g_strcmp0(name, "bottom") == 0) return GDK_WINDOW_EDGE_SOUTH;
  if (g_strcmp0(name, "left") == 0) return GDK_WINDOW_EDGE_WEST;
  if (g_strcmp0(name, "right") == 0) return GDK_WINDOW_EDGE_EAST;
  if (g_strcmp0(name, "topLeft") == 0) return GDK_WINDOW_EDGE_NORTH_WEST;
  if (g_strcmp0(name, "topRight") == 0) return GDK_WINDOW_EDGE_NORTH_EAST;
  if (g_strcmp0(name, "bottomLeft") == 0) return GDK_WINDOW_EDGE_SOUTH_WEST;
  return GDK_WINDOW_EDGE_SOUTH_EAST;
}

// Handles calls from the Dart custom title bar.
static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "startDrag") == 0) {
    gint x = 0, y = 0;
    pointer_root_position(window, &x, &y);
    release_flutter_pointer(window);
    gtk_window_begin_move_drag(window, 1, x, y, gtk_get_current_event_time());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "startResize") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* edge = (args != nullptr &&
                         fl_value_get_type(args) == FL_VALUE_TYPE_STRING)
                            ? fl_value_get_string(args)
                            : "bottomRight";
    gint x = 0, y = 0;
    pointer_root_position(window, &x, &y);
    release_flutter_pointer(window);
    gtk_window_begin_resize_drag(window, edge_from_name(edge), 1, x, y,
                                 gtk_get_current_event_time());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "isMaximized") == 0) {
    g_autoptr(FlValue) value =
        fl_value_new_bool(gtk_window_is_maximized(window));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // MindGrid draws its own title bar. An empty client-side titlebar removes
  // the window manager's decoration while keeping GTK's resize borders and
  // drop shadow.
  GtkWidget* titlebar = gtk_fixed_new();
  gtk_window_set_titlebar(window, titlebar);
  gtk_window_set_title(window, "MindGrid");

  // Without a compositor GTK paints a solid frame around client-side
  // decorated windows; keep it (it is the resize border) but match the app.
  GtkCssProvider* css = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      css,
      ".solid-csd decoration {"
      "  padding: 3px;"
      "  border: 1px solid #2A2825;"
      "  background-color: #100F0D;"
      "  box-shadow: none;"
      "}"
      "decoration { border-radius: 0; }",
      -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      gtk_window_get_screen(window), GTK_STYLE_PROVIDER(css),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
  g_object_unref(css);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(GdkPixbuf) icon = load_app_icon();
  if (icon != nullptr) {
    gtk_window_set_icon(window, icon);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#100F0D");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Window controls for the custom title bar.
  g_object_set_data(G_OBJECT(window), "mindgrid-fl-view", view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "mindgrid/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, window, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
