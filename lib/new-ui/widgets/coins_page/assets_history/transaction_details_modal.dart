import 'package:cake_wallet/entities/new_ui_entities/list_item/list_item_regular_row.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/new-ui/widgets/receive_page/receive_top_bar.dart';
import 'package:cake_wallet/src/widgets/new_list_row/new_list_section.dart';
import 'package:cake_wallet/view_model/transaction_details_view_model.dart';
import 'package:flutter/material.dart';

class TransactionDetailsModal extends StatefulWidget {
  const TransactionDetailsModal({super.key, required this.transactionDetailsViewModel});

  final TransactionDetailsViewModel transactionDetailsViewModel;

  @override
  State<TransactionDetailsModal> createState() => _TransactionDetailsModalState();
}

class _TransactionDetailsModalState extends State<TransactionDetailsModal> {
  final TextEditingController noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.25,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (context, controller) => SafeArea(
              child: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                    child: Column(
                      children: [
                        ModalTopBar(
                          title: S.of(context).transaction,
                          leadingIcon: Icon(Icons.close),
                          onLeadingPressed: Navigator.of(context).pop,
                        ),
                        Column(
                          children: [
                            Column(
                              children: [
                                Image.asset(
                                    widget.transactionDetailsViewModel.transactionAsset.iconPath ??
                                        "",
                                    width: 64,
                                    height: 64),
                                SizedBox(height: 10),
                                Text(
                                  widget.transactionDetailsViewModel.formattedTitle +
                                      widget.transactionDetailsViewModel.formattedStatus,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  widget.transactionDetailsViewModel.transactionInfo
                                      .amountFormatted(),
                                  style: TextStyle(fontSize: 28),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    spacing: 12,
                                    children: [
                                      NewListSections(sections: {
                                        "": widget.transactionDetailsViewModel.items
                                            .map((item) => ListItemRegularRow(
                                                showArrow: false,
                                                keyValue:
                                                    ((item.key as ValueKey?)?.value as String?) ??
                                                        item.title,
                                                label: item.title,
                                                trailingText:
                                                    item.value.length <= 25 ? item.value : null,
                                                bottomWidget: item.value.length <= 25
                                                    ? null
                                                    : Text(
                                                        item.value,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant),
                                                      )))
                                            .toList(),
                                      }),
                                      Container(
                                        decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            color: Theme.of(context).colorScheme.surfaceContainer),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            spacing: 8,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(S.of(context).note),
                                              TextField(
                                                onEditingComplete: () => widget
                                                    .transactionDetailsViewModel
                                                    .updateNote(noteController.text),
                                                decoration: InputDecoration(
                                                    hintText: S.of(context).add_a_note,
                                                    border: InputBorder.none,
                                                    focusedBorder: InputBorder.none,
                                                    enabledBorder: InputBorder.none,
                                                    contentPadding: EdgeInsets.zero,
                                                    isDense: true),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                      NewListSections(sections: {
                                        "view tx": [
                                          ListItemRegularRow(
                                              keyValue: "view tx on",
                                              label: widget
                                                  .transactionDetailsViewModel.explorerDescription,
                                              onTap:
                                                  widget.transactionDetailsViewModel.launchExplorer)
                                        ]
                                      })
                                    ],
                                  ),
                                )
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ));
  }
}
