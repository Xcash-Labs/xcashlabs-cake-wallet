import 'package:flutter/material.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/entities/xcash_delegate.dart';
import 'package:cake_wallet/entities/xcash_delegates_api.dart';

class VotePage extends BasePage {
  VotePage({required this.wallet});

  final MoneroWallet wallet;

  @override
  String get title => S.current.vote;

  @override
  bool get gradientAll => true;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => false;

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  Widget? leading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios, size: 18),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget body(BuildContext context) {
    return _VotePageBody(wallet: wallet);
  }
}

class _VotePageBody extends StatefulWidget {
  const _VotePageBody({required this.wallet});

  final MoneroWallet wallet;

  @override
  State<_VotePageBody> createState() => _VotePageBodyState();
}

class _VotePageBodyState extends State<_VotePageBody> {
  String status = S.current.loading_msg;
  bool isLoading = true;
  bool isRevoting = false;
  bool isVoting = false;
  bool isSweeping = false;
  

  List<XCashDelegate> delegates = [];
  bool loadingDelegates = false;
  String? delegatesError;

  @override
  void initState() {
    super.initState();
    loadVoteStatus();
  }

  Future<void> loadVoteStatus() async {
    setState(() => isLoading = true);

    try {
      final result = await widget.wallet.voteStatus();

      if (!mounted) return;

      setState(() {
        status = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> submitRevote() async {
    if (isRevoting) return;

    setState(() {
      isRevoting = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {

        final result = await widget.wallet.revote();

        if (!mounted) return;

        await loadVoteStatus();

        if (!mounted) return;

        String message = result;

        if (result.contains('proof is too large')) {
          message = S.current.sweep_error;
        } else if (result.startsWith('No revote needed')) {
          message = S.current.no_revote;
        } else if (result.contains('sent successfully')) {
          message = S.current.success;
        } else {
          message = '${S.current.revote_failed}: $result';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );

      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
           content: Text('${S.current.revote_failed}: $e'),
          ),
        );

      } finally {
        if (mounted) {
          setState(() {
            isRevoting = false;
          });
        }
      }
    });
  }

  Future<void> submitVote(String delegateName) async {
    if (isVoting) return;

    setState(() {
      isVoting = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final result = await widget.wallet.vote('$delegateName|ALL');

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        await loadVoteStatus();

        if (!mounted) return;

        String message = result;

        if (result.contains('proof is too large')) {
          message = S.current.sweep_error;
        } else if (result.contains('sent successfully')) {
          message = S.current.success;
        } else {
          message = '${S.current.vote_failed}: $result';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );

      } catch (e) {
        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.current.vote_failed}: $e'),
          ),
        );

      } finally {
        if (mounted) {
          setState(() {
            isVoting = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voteStatus = VoteStatusInfo.fromRaw(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [

          Expanded(
            child: SingleChildScrollView(
              child: _VoteStatusCard(
                isLoading: isLoading,
                status: voteStatus,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Column(
            children: [

              if (voteStatus.hasVote) ...[
                PrimaryButton(
                  onPressed: submitRevote,
                  text: isRevoting
                      ? S.current.submitting_revote
                      : S.current.revote,
                  color: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                ),

                const SizedBox(height: 12),
              ],

              PrimaryButton(
                onPressed: () async {
                  try {
                    setState(() {
                      loadingDelegates = true;
                      delegatesError = null;
                    });

                    delegates = await XCashDelegatesApi()
                        .getSharedOnlineDelegates();

                    setState(() {
                      loadingDelegates = false;
                    });

                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.70,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    S.current.select_delegate,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                  ),

                                  const SizedBox(height: 16),

                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: delegates.length > 50 ? 50 : delegates.length,
                                      itemBuilder: (context, index) {
                                        final delegate = delegates[index];

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              Navigator.pop(context);

                                              showDialog<void>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (_) => AlertDialog(
                                                  content: Text(S.current.submitting_vote),
                                                ),
                                              );

                                              Future.delayed(const Duration(milliseconds: 300), () {
                                                submitVote(delegate.delegateName);
                                              });
                                            },                                          
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.outlineVariant,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    delegate.delegateName,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight: FontWeight.w700,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                        ),
                                                  ),

                                                  const SizedBox(height: 8),

                                                  Text(
                                                    S.current.delegate_fee_votes
                                                      .replaceAll(
                                                        '{fee}',
                                                        delegate.fee % 100 == 0
                                                            ? (delegate.fee / 100).toStringAsFixed(0)
                                                            : (delegate.fee / 100).toStringAsFixed(2),
                                                      )
                                                      .replaceAll('{votes}', delegate.votesDisplay),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );

                  } catch (e) {
                    setState(() {
                      loadingDelegates = false;
                      delegatesError = e.toString();
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${S.current.failed_to_load_delegates}: $e',
                        ),
                      ),
                    );
                  }
                },
                text: S.current.vote,
                color: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.onPrimary,
              ),

              const SizedBox(height: 12),
              PrimaryButton(
                onPressed: isSweeping
                    ? null
                    : () async {
                        setState(() {
                          isSweeping = true;
                        });

                        try {
                          final success = await widget.wallet.sweepAllToPrimary();

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success ? S.current.sweep_success : S.current.sweep_failed,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${S.current.sweep_failed}: $e'),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              isSweeping = false;
                            });
                          }
                        }
                      },
                text: isSweeping
                    ? S.current.sweeping_wallet_progress
                    : S.current.sweep_wallet,
                color: Colors.transparent,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                isDottedBorder: true,
                borderColor: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VoteStatusInfo {
  final bool hasVote;
  final bool hasError;
  final String total;
  final String delegateName;
  final String error;

  const VoteStatusInfo({
    required this.hasVote,
    required this.hasError,
    required this.total,
    required this.delegateName,
    required this.error,
  });

  factory VoteStatusInfo.fromRaw(String raw) {
    final trimmed = raw.trim();

    if (trimmed.startsWith('Error:')) {
      return VoteStatusInfo(
        hasVote: false,
        hasError: true,
        total: '',
        delegateName: '',
        error: trimmed,
      );
    }

    if (!trimmed.startsWith('Vote found:')) {
      return const VoteStatusInfo(
        hasVote: false,
        hasError: false,
        total: '',
        delegateName: '',
        error: '',
      );
    }

    final totalMatch = RegExp(r'total:([^,]+)').firstMatch(trimmed);
    final delegateMatch = RegExp(r'delegate:(.+)$').firstMatch(trimmed);

    return VoteStatusInfo(
      hasVote: true,
      hasError: false,
      total: totalMatch?.group(1)?.trim() ?? '',
      delegateName: delegateMatch?.group(1)?.trim() ?? '',
      error: '',
    );
  }
}

class _VoteStatusCard extends StatelessWidget {
  const _VoteStatusCard({
    required this.isLoading,
    required this.status,
  });

  final bool isLoading;
  final VoteStatusInfo status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : status.hasError
              ? Text(
                  status.error,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                )
              : status.hasVote
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VoteField(
                          label: S.current.vote_total,
                          value: status.total,
                        ),

                        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),

                        const SizedBox(height: 18),
                        _VoteField(
                          label: S.current.vote_delegate,
                          value: status.delegateName,
                        ),
                      ],
                    )
                  : Text(
                      S.current.wallet_has_not_voted_yet,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
    );
  }
}

class _VoteField extends StatelessWidget {
  const _VoteField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}