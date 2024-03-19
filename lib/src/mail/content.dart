class Content {
  /// The Blade view that represents the text version of the message.
  final String? text;

  /// The Blade view that should be rendered for the mailable.
  final String? html;

  const Content({
    this.text,
    this.html,
  });
}
