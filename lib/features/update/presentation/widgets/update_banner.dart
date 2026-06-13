import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_track/features/update/presentation/cubit/update_cubit.dart';
import 'package:watch_track/features/update/presentation/cubit/update_state.dart';
import 'package:watch_track/features/update/presentation/screens/update_screen.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateCubit, UpdateState>(
      builder: (context, state) {
        if (state is UpdateAvailable && !state.isForced) {
          return Container(
            color: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Antigravity v\${state.update.versionName} is available.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<UpdateCubit>(),
                          child: const UpdateScreen(),
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
