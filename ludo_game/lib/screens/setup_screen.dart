import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/player_color.dart';
import '../providers/game_provider.dart';
import '../utils/page_transitions.dart';
import 'game_screen.dart';

/// Lets the player choose how many people are playing (2-4) and which
/// color each of them gets, before a match starts.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const List<PlayerColor> _defaultOrder = [
    PlayerColor.red,
    PlayerColor.green,
    PlayerColor.yellow,
    PlayerColor.blue,
  ];

  List<PlayerColor> _slotColors = _defaultOrder.take(4).toList();
  final List<TextEditingController> _nameControllers = List.generate(
    4,
    (i) => TextEditingController(text: 'Player ${i + 1}'),
  );

  @override
  void dispose() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _enableBlocking = true;
  bool _enableExtraTurnOnCapture = true;
  bool _eatAllOnBlocked = false;
  bool _endOnFirstWinner = false;

  void _setPlayerCount(int count) {
    setState(() {
      if (count > _slotColors.length) {
        final remaining =
            PlayerColor.values.where((c) => !_slotColors.contains(c)).toList();
        _slotColors = [..._slotColors, ...remaining.take(count - _slotColors.length)];
      } else {
        _slotColors = _slotColors.sublist(0, count);
      }
    });
  }

  void _selectColorForSlot(int slotIndex, PlayerColor color) {
    setState(() {
      final existingIndex = _slotColors.indexOf(color);
      if (existingIndex != -1 && existingIndex != slotIndex) {
        // That color is already taken by another slot — swap them so
        // every slot always holds a distinct color.
        final temp = _slotColors[slotIndex];
        _slotColors[slotIndex] = color;
        _slotColors[existingIndex] = temp;
      } else {
        _slotColors[slotIndex] = color;
      }
    });
  }

  void _startMatch() {
    final provider = context.read<GameProvider>();
    provider.enableBlocking = _enableBlocking;
    provider.enableExtraTurnOnCapture = _enableExtraTurnOnCapture;
    provider.eatAllOnBlocked = _eatAllOnBlocked;
    provider.endOnFirstWinner = _endOnFirstWinner;
    
    final names = _nameControllers.sublist(0, _slotColors.length)
        .map((c) => c.text.trim().isEmpty ? 'Unknown' : c.text.trim())
        .toList();
        
    provider.initGame(_slotColors, names: names);
    Navigator.of(context).pushReplacement(
      FadeScaleRoute(page: GameScreen(colors: _slotColors)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int playerCount = _slotColors.length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        foregroundColor: AppColors.appBarText,
        title: Text(
          'New Match',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Players',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [2, 3, 4].map((count) {
                        final bool selected = count == playerCount;
                        return Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: ChoiceChip(
                            label: Text('$count'),
                            selected: selected,
                            onSelected: (_) => _setPlayerCount(count),
                            selectedColor: AppColors.red,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.appBarText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'Assign colors',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Tap a color to give it to that player. Colors already in use swap automatically.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                    ),
                    SizedBox(height: 12.h),
                    ...List.generate(playerCount, (index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _PlayerSlotRow(
                          slotIndex: index,
                          selectedColor: _slotColors[index],
                          nameController: _nameControllers[index],
                          onColorSelected: (c) => _selectColorForSlot(index, c),
                        )
                            .animate()
                            .fadeIn(delay: (60 * index).ms, duration: 300.ms)
                            .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                      );
                    }),
                    SizedBox(height: 20.h),
                    Text(
                      'House rules',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Fine-tune the classic rules for this match.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                    ),
                    SizedBox(height: 8.h),
                    _HouseRuleTile(
                      title: 'Blocking',
                      subtitle: 'Two of your tokens on one cell wall off opponents.',
                      value: _enableBlocking,
                      onChanged: (v) => setState(() => _enableBlocking = v),
                    ),
                    _HouseRuleTile(
                      title: 'Extra turn on capture',
                      subtitle: 'Send an opponent home and roll again.',
                      value: _enableExtraTurnOnCapture,
                      onChanged: (v) => setState(() => _enableExtraTurnOnCapture = v),
                    ),
                    _HouseRuleTile(
                      title: 'Eat All',
                      subtitle: 'When landing on multiple identical opponents, eat them all instead of just one.',
                      value: _eatAllOnBlocked,
                      onChanged: (v) => setState(() => _eatAllOnBlocked = v),
                    ),
                    _HouseRuleTile(
                      title: 'Play for full standings',
                      subtitle: 'Keep going after the first win to rank everyone.',
                      value: !_endOnFirstWinner,
                      onChanged: (v) => setState(() => _endOnFirstWinner = !v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: _startMatch,
                  child: Text(
                    'START MATCH',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseRuleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HouseRuleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        // SwitchListTile paints its background/ink splashes on the
        // nearest Material ancestor — giving it its own Material here
        // (instead of just a colored Container) keeps that visible
        // and avoids Flutter's "background may be invisible" warning.
        color: Colors.white,
        child: SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
          activeThumbColor: AppColors.red,
          title: Text(
            title,
            style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 11.5.sp, color: Colors.black54),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PlayerSlotRow extends StatelessWidget {
  final int slotIndex;
  final PlayerColor selectedColor;
  final TextEditingController nameController;
  final ValueChanged<PlayerColor> onColorSelected;

  const _PlayerSlotRow({
    required this.slotIndex,
    required this.selectedColor,
    required this.nameController,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextField(
                  controller: nameController,
                  maxLength: 12,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                    border: const UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: selectedColor.displayColor,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Wrap(
              spacing: 10.w,
              children: PlayerColor.values.map((color) {
                final bool isSelected = color == selectedColor;
                return GestureDetector(
                  onTap: () => onColorSelected(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      gradient: AppColors.glossSphere(
                        color.displayColor,
                        AppColors.darkFromKey(color.key),
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.white,
                        width: isSelected ? 3.w : 2.w,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.displayColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
