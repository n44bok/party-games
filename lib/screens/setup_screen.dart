import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/category_chips.dart';
import '../widgets/glass.dart';
import '../widgets/glass_blob.dart';
import '../widgets/glass_pill.dart';
import '../widgets/multi_select.dart';
import '../widgets/gradient_background.dart';
import '../spy/spy_round.dart';
import '../mafia/mafia_round.dart';
import 'charades_game_screen.dart';
import 'game_screen.dart';
import 'reverse_song_screen.dart';
import 'mafia_game_screen.dart';
import 'spy_game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.mode});

  final GameMode mode;

  static const maxPlayers = 12;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _maxNameLength = 14;
  static const _timerMinutes = [5, 8, 10, 15];
  static const _roundChoices = [1, 2, 3, 4, 5];

  /// One controller per player; its length is the player count.
  late final _names = <TextEditingController>[
    for (var i = 0; i < widget.mode.defaultPlayers; i++)
      TextEditingController(),
  ];
  Category? _category;

  // Spy options.
  /// The chosen word categories: any number, but never none.
  final _spyCategories = <SpyCategory>{SpyCategory.places};

  /// The word typed for "One word"; only for this game, never saved.
  final _singleWord = TextEditingController();
  int _spies = 1;
  int _minutes = 8;

  // Charades options.
  int _turnSeconds = 60;
  int _rounds = 1;

  // Mafia options.
  int _mafia = 1;
  bool _doctor = true;
  bool _detective = true;
  bool _appRunsNights = true;

  /// The time warning is part of this game's options; the choice is
  /// remembered between games.
  late bool _timeWarning = SettingsScope.read(context).timeWarning;

  @override
  void initState() {
    super.initState();
    if (widget.mode == GameMode.charades) {
      // Words that are fun to act out.
      _spyCategories
        ..clear()
        ..addAll(const [
          SpyCategory.animals,
          SpyCategory.jobs,
          SpyCategory.objects,
          SpyCategory.sports,
          SpyCategory.food,
        ]);
    }
    if (widget.mode.hasStartAd) {
      // Spy and Mafia show their one ad when the game starts, so have it loaded by then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdScope.read(context).prepareInterstitial();
      });
    }
  }

  int get _players => _names.length;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    _singleWord.dispose();
    super.dispose();
  }

  void _changePlayers(int delta) => setState(() {
    final target = (_players + delta).clamp(
      widget.mode.minPlayers,
      SetupScreen.maxPlayers,
    );
    while (_names.length < target) {
      _names.add(TextEditingController());
    }
    while (_names.length > target) {
      _names.removeLast().dispose();
    }
    // Fewer players may no longer allow as many spies.
    _spies = _spies.clamp(1, SpyRound.maxSpiesFor(_players));
    _mafia = _mafia.clamp(1, MafiaRound.maxMafiaFor(_players));
  });

  void _start() {
    final s = Strings.of(context);
    FocusScope.of(context).unfocus();
    // A message from an earlier refused start must not linger over the game
    // screen and cover its buttons.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // "My word": there must be a word to play with.
    final ownWord = SettingsController.cleanSpyWord(_singleWord.text);
    if (widget.mode == GameMode.spy &&
        _spyCategories.contains(SpyCategory.single) &&
        ownWord == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s['spy_single_empty'])));
      return;
    }

    // An empty field falls back to "Player N".
    final names = [
      for (var i = 0; i < _players; i++)
        _names[i].text.trim().isEmpty
            ? s.defaultPlayerName(i + 1)
            : _names[i].text.trim(),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (widget.mode) {
          GameMode.mafia => MafiaGameScreen(
            playerNames: names,
            mafia: _mafia,
            doctor: _doctor,
            detective: _detective,
            appRunsNights: _appRunsNights,
            duration: Duration(minutes: _minutes),
          ),
          GameMode.reverseSong => ReverseSongScreen(
            playerNames: names,
            rounds: _rounds,
          ),
          GameMode.charades => CharadesGameScreen(
            playerNames: names,
            categories: Set.of(_spyCategories),
            turnSeconds: _turnSeconds,
            rounds: _rounds,
          ),
          GameMode.spy => SpyGameScreen(
            playerNames: names,
            spies: _spies,
            duration: Duration(minutes: _minutes),
            categories: Set.of(_spyCategories),
            ownWord: _spyCategories.contains(SpyCategory.single)
                ? ownWord
                : null,
            timeWarning: _timeWarning,
          ),
          _ => GameScreen(
            mode: widget.mode,
            playerNames: names,
            category: _category,
          ),
        },
      ),
    );
  }

  /// Turns a category on or off. At least one always stays on, so there is
  /// always something to draw the word from.
  void _toggleCategory(SpyCategory category) => setState(() {
    if (_spyCategories.contains(category)) {
      if (_spyCategories.length > 1) _spyCategories.remove(category);
    } else {
      _spyCategories.add(category);
    }
  });

  /// Selects every ready-made category; if they all are selected already,
  /// goes back to the default (Places). "My word" is left as it is.
  void _selectAllCategories() => setState(() {
    final builtIn = SpyCategory.builtIn;
    if (builtIn.every(_spyCategories.contains)) {
      _spyCategories
        ..removeAll(builtIn)
        ..add(SpyCategory.places);
    } else {
      _spyCategories.addAll(builtIn);
    }
  });

  /// What the closed field says: "All categories", or the first two chosen
  /// followed by how many more there are.
  String _categorySummary(Strings s) {
    final builtIn = [
      for (final c in SpyCategory.builtIn)
        if (_spyCategories.contains(c)) c,
    ];
    final names = [
      if (builtIn.length == SpyCategory.builtIn.length)
        s['spy_all_categories']
      else
        for (final c in builtIn) s[c.labelKey],
      if (_spyCategories.contains(SpyCategory.single))
        s[SpyCategory.single.labelKey],
    ];
    if (names.length <= 2) return names.join(', ');
    return '${names[0]}, ${names[1]} +${names.length - 2}';
  }

  /// The options below the player list: content categories for the card
  /// games, spies and timer for Spy.
  List<Widget> _modeOptions(Strings s, ThemeData theme) {
    Widget header(IconData icon, String label) => Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.titleMedium),
      ],
    );
    final divider = Divider(
      height: 32,
      color: Colors.white.withValues(alpha: 0.14),
    );

    if (widget.mode == GameMode.mafia) return _mafiaOptions(s, header, divider);
    if (widget.mode == GameMode.charades) {
      return _charadesOptions(s, header, divider);
    }
    if (widget.mode == GameMode.reverseSong) {
      return _reverseSongOptions(s, header, divider);
    }

    if (widget.mode != GameMode.spy) {
      return [
        divider,
        header(Icons.layers_outlined, s['category']),
        const SizedBox(height: 14),
        CategoryChips(
          selected: _category,
          onSelected: (c) => setState(() => _category = c),
        ),
      ];
    }

    final maxSpies = SpyRound.maxSpiesFor(_players);
    return [
      divider,
      header(Icons.category_outlined, s['spy_words']),
      const SizedBox(height: 14),
      MultiSelectField<SpyCategory>(
        fieldKey: const Key('spyCategorySelector'),
        options: [
          for (final c in SpyCategory.builtIn)
            MultiSelectOption(value: c, id: c.id, label: s[c.labelKey]),
          // The players' own word sits apart from the ready-made categories.
          MultiSelectOption(
            value: SpyCategory.single,
            id: SpyCategory.single.id,
            label: s[SpyCategory.single.labelKey],
            separated: true,
          ),
        ],
        selected: _spyCategories,
        summary: _categorySummary(s),
        title: s['spy_pick_categories'],
        selectAllLabel: s['select_all'],
        doneLabel: s['done'],
        onToggle: _toggleCategory,
        onSelectAll: _selectAllCategories,
        allSelected: () => SpyCategory.builtIn.every(_spyCategories.contains),
      ),
      // "My word" is one of the choices, so its field is right there as soon
      // as it is selected.
      if (_spyCategories.contains(SpyCategory.single)) ...[
        const SizedBox(height: 14),
        _SingleWordField(controller: _singleWord),
      ],
      const SizedBox(height: 24),
      header(Icons.person_search_outlined, s['spies']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('spyCountPills'),
        options: const [(1, '1'), (2, '2')],
        selected: _spies,
        isEnabled: (n) => n <= maxSpies,
        onSelected: (n) => setState(() => _spies = n),
      ),
      const SizedBox(height: 24),
      header(Icons.timer_outlined, s['timer']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('timerPills'),
        options: [
          for (final m in _timerMinutes) (m, s.format('minutes', {'n': m})),
        ],
        selected: _minutes,
        onSelected: (m) => setState(() => _minutes = m),
      ),
      const SizedBox(height: 18),
      _TimeWarningRow(
        value: _timeWarning,
        onChanged: (value) {
          setState(() => _timeWarning = value);
          SettingsScope.read(context).setTimeWarning(value); // remember it
        },
      ),
    ];
  }

  /// Song Backwards: only the number of rounds (the singers stop their own
  /// recordings).
  List<Widget> _reverseSongOptions(
    Strings s,
    Widget Function(IconData, String) header,
    Widget divider,
  ) {
    return [
      divider,
      header(Icons.repeat_rounded, s['rounds']),
      const SizedBox(height: 14),
      _roundsPills(),
    ];
  }

  Widget _roundsPills() => OptionPills<int>(
    key: const Key('roundsPills'),
    options: [for (final n in _roundChoices) (n, '$n')],
    selected: _rounds,
    onSelected: (n) => setState(() => _rounds = n),
  );

  /// Charades: word categories, time per turn and rounds.
  List<Widget> _charadesOptions(
    Strings s,
    Widget Function(IconData, String) header,
    Widget divider,
  ) {
    return [
      divider,
      header(Icons.category_outlined, s['spy_words']),
      const SizedBox(height: 14),
      MultiSelectField<SpyCategory>(
        fieldKey: const Key('spyCategorySelector'),
        options: [
          for (final c in SpyCategory.builtIn)
            MultiSelectOption(value: c, id: c.id, label: s[c.labelKey]),
        ],
        selected: _spyCategories,
        summary: _categorySummary(s),
        title: s['spy_pick_categories'],
        selectAllLabel: s['select_all'],
        doneLabel: s['done'],
        onToggle: _toggleCategory,
        onSelectAll: _selectAllCategories,
        allSelected: () => SpyCategory.builtIn.every(_spyCategories.contains),
      ),
      const SizedBox(height: 24),
      header(Icons.timer_outlined, s['turn_time']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('turnTimePills'),
        options: [
          for (final n in const [30, 60, 90])
            (n, s.format('seconds', {'n': n})),
        ],
        selected: _turnSeconds,
        onSelected: (n) => setState(() => _turnSeconds = n),
      ),
      const SizedBox(height: 24),
      header(Icons.repeat_rounded, s['rounds']),
      const SizedBox(height: 14),
      _roundsPills(),
    ];
  }

  /// Mafia: how many mafia members, which special roles, a host, the timer.
  List<Widget> _mafiaOptions(
    Strings s,
    Widget Function(IconData, String) header,
    Widget divider,
  ) {
    final maxMafia = MafiaRound.maxMafiaFor(_players);
    return [
      divider,
      header(Icons.nightlight_outlined, s['mafia_members']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('mafiaCountPills'),
        options: const [(1, '1'), (2, '2'), (3, '3')],
        selected: _mafia,
        isEnabled: (n) => n <= maxMafia,
        onSelected: (n) => setState(() => _mafia = n),
      ),
      const SizedBox(height: 20),
      _OptionSwitchRow(
        icon: Icons.medical_services_outlined,
        title: s['doctor_option'],
        description: s['doctor_option_desc'],
        switchKey: const Key('doctorSwitch'),
        value: _doctor,
        onChanged: (v) => setState(() => _doctor = v),
      ),
      const SizedBox(height: 14),
      _OptionSwitchRow(
        icon: Icons.search_rounded,
        title: s['detective_option'],
        description: s['detective_option_desc'],
        switchKey: const Key('detectiveSwitch'),
        value: _detective,
        onChanged: (v) => setState(() => _detective = v),
      ),
      const SizedBox(height: 14),
      _OptionSwitchRow(
        icon: Icons.record_voice_over_outlined,
        title: s['app_nights_option'],
        description: s['app_nights_option_desc'],
        switchKey: const Key('nightsSwitch'),
        value: _appRunsNights,
        onChanged: (v) => setState(() => _appRunsNights = v),
      ),
      const SizedBox(height: 24),
      header(Icons.timer_outlined, s['timer']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('timerPills'),
        options: [
          for (final m in _timerMinutes) (m, s.format('minutes', {'n': m})),
        ],
        selected: _minutes,
        onSelected: (m) => setState(() => _minutes = m),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mode = widget.mode;
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        // The illustration is part of the scrolling page, anchored under the
        // button; the name fields can make the page taller than the screen.
        // No SafeArea at the top: the scroll view must reach the screen edge,
        // otherwise it clips the blob's glow along the status-bar line. The
        // top inset (which already includes the app bar, because the body extends
        // behind it) is added as padding inside instead.
        child: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final backdropHeight = MediaQuery.sizeOf(context).height * 0.36;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: backdropHeight,
                        child: const _PartyBackdrop(),
                      ),
                      Padding(
                        // Leave room so the button sits above the picture.
                        padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.paddingOf(context).top,
                          20,
                          backdropHeight * 0.6,
                        ),
                        child: Column(
                          children: [
                            _ModeBlob(mode: mode),
                            const SizedBox(height: 14),
                            _ModeTitle(title: s.modeName(mode)),
                            const SizedBox(height: 6),
                            Text(
                              s['${mode.id}_desc'],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.group_outlined),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          s['players'],
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      GlassIconButton(
                                        icon: Icons.remove,
                                        tooltip: '−',
                                        onPressed: _players > mode.minPlayers
                                            ? () => _changePlayers(-1)
                                            : null,
                                      ),
                                      SizedBox(
                                        width: 48,
                                        child: Text(
                                          '$_players',
                                          key: const Key('playersCount'),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      GlassIconButton(
                                        icon: Icons.add,
                                        tooltip: '+',
                                        onPressed:
                                            _players < SetupScreen.maxPlayers
                                            ? () => _changePlayers(1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  for (var i = 0; i < _players; i++) ...[
                                    if (i > 0) const SizedBox(height: 10),
                                    _NameField(
                                      controller: _names[i],
                                      hint: s.defaultPlayerName(i + 1),
                                      maxLength: _maxNameLength,
                                      isLast: i == _players - 1,
                                    ),
                                  ],
                                  ..._modeOptions(s, theme),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            GradientButton(
                              label: s['start'],
                              icon: Icons.play_arrow_rounded,
                              onPressed: _start,
                            ),
                            // Banner under the button; takes no space until
                            // an ad has loaded.
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Center(
                                child: AdScope.of(context).buildBanner(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Single-line glass text field for one player's name.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.isLast,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: alpha)),
    );
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: 1,
      textCapitalization: TextCapitalization.words,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: border(0.16),
        focusedBorder: border(0.6),
        border: border(0.16),
      ),
    );
  }
}

/// "Time warning": a switch with a one-line explanation, inside the Spy
/// options.
class _TimeWarningRow extends StatelessWidget {
  const _TimeWarningRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.hourglass_bottom_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['time_warning'], style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                s['time_warning_desc'],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Switch(
          key: const Key('timeWarningSwitch'),
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFFB45CF5),
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }
}

/// A titled switch with a short description under the title.
class _OptionSwitchRow extends StatelessWidget {
  const _OptionSwitchRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final Key switchKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFFB45CF5),
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }
}

/// The players' own word for this game: typed here, never saved.
class _SingleWordField extends StatelessWidget {
  const _SingleWordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: alpha)),
    );
    return TextField(
      key: const Key('singleWordField'),
      controller: controller,
      maxLength: SettingsController.maxSpyWordLength,
      maxLines: 1,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: s['spy_single_hint'],
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border(0.16),
        enabledBorder: border(0.16),
        focusedBorder: border(0.6),
      ),
    );
  }
}

/// Mode icon on a glass blob, filled with the mode's own gradient.
class _ModeBlob extends StatelessWidget {
  const _ModeBlob({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return GlassBlob(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: mode == GameMode.truthOrDare
              ? const [Color(0xFFFFB074), Color(0xFFFF4F92)] // warm flame
              : [mode.tint, mode.glow],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
        child: Icon(mode.icon, size: 96, color: Colors.white),
      ),
    );
  }
}

/// Title where the connecting word ("or" / "чи") gets a lavender accent.
class _ModeTitle extends StatelessWidget {
  const _ModeTitle({required this.title});

  final String title;

  static final _connector = RegExp(r'( or | чи )');

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 38,
      height: 1.1,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    final match = _connector.firstMatch(title);
    if (match == null) {
      return Text(title, textAlign: TextAlign.center, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: title.substring(0, match.start)),
          TextSpan(
            text: match.group(0),
            style: const TextStyle(color: Color(0xFFC9A8FF)),
          ),
          TextSpan(text: title.substring(match.end)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Illustration of friends toasting, anchored to the bottom and faded into
/// the background at the top.
class _PartyBackdrop extends StatelessWidget {
  const _PartyBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.45],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
        child: Image.asset(
          'assets/images/party_toast.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          // Decorative only; never break the screen over a missing image.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
