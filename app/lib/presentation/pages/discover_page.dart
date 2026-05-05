// Presentation page: DiscoverPage.
//
// '/discover' route. Shows the proximity radar, the live peer list,
// a Bluetooth-state aware error UI, and a single Switch that
// starts/stops the underlying DiscoveryController.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/discovery_status.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/presentation/state/discovery_providers.dart';
import 'package:proximity_music_app/presentation/widgets/peer_list_tile.dart';
import 'package:proximity_music_app/presentation/widgets/ripple_radar.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = ref.watch(bluetoothStateProvider);
    final status = ref.watch(discoveryStatusProvider);
    final peers = ref.watch(peersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: bt == BluetoothState.off || bt == BluetoothState.unauthorized
            ? _BluetoothErrorBody(state: bt)
            : _DiscoverBody(status: status, peers: peers),
      ),
    );
  }
}

class _BluetoothErrorBody extends StatelessWidget {
  const _BluetoothErrorBody({required this.state});

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            color: Color(0xFFFF6B6B),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bluetooth が無効です。設定を確認してください',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Real OS-settings deep link arrives in Issue #4.
            },
            child: const Text('Bluetooth を有効化'),
          ),
        ],
      ),
    );
  }
}

class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody({required this.status, required this.peers});

  final DiscoveryStatus status;
  final List<Peer> peers;

  bool get _scanning =>
      status == DiscoveryStatus.scanning || status == DiscoveryStatus.starting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(discoveryControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Discovery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: _scanning,
                activeColor: const Color(0xFF1DB954),
                onChanged: (on) {
                  if (on) {
                    controller.start();
                  } else {
                    controller.stop();
                  }
                },
              ),
            ],
          ),
        ),
        Center(child: RippleRadarView(active: _scanning, size: 200)),
        const SizedBox(height: 8),
        Expanded(
          child: peers.isEmpty
              ? const _EmptyPeers()
              : ListView.builder(
                  itemCount: peers.length,
                  itemBuilder: (context, i) => PeerListTile(peer: peers[i]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${peers.length} 台検知中',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPeers extends StatelessWidget {
  const _EmptyPeers();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            '周囲に誰もいません。場所を変えてみてください',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
