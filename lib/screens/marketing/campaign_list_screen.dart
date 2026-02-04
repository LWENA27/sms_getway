import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/marketing_campaign.dart';
import '../../core/tenant_service.dart';
import 'campaign_create_screen.dart';

/// Campaign List Screen
/// Displays all marketing campaigns with stats and actions
class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  final _supabase = Supabase.instance.client;
  final _tenantService = TenantService();
  List<MarketingCampaign> _campaigns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) {
        throw Exception('No tenant selected');
      }

      final response = await _supabase
          .schema('sms_gateway')
          .from('marketing_campaigns')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      final campaigns = (response as List)
          .map((json) => MarketingCampaign.fromJson(json))
          .toList();

      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleCampaignStatus(MarketingCampaign campaign) async {
    String newStatus;
    if (campaign.isActive) {
      newStatus = 'paused';
    } else if (campaign.isPaused) {
      newStatus = 'active';
    } else {
      return; // Can't toggle draft or completed
    }

    try {
      await _supabase.schema('sms_gateway').from('marketing_campaigns').update({
        'status': newStatus,
        if (newStatus == 'active' && campaign.activatedAt == null)
          'activated_at': DateTime.now().toIso8601String(),
      }).eq('id', campaign.id);

      _loadCampaigns();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'active'
                  ? '✅ Campaign activated'
                  : '⏸️ Campaign paused',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCampaign(MarketingCampaign campaign) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Delete "${campaign.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .schema('sms_gateway')
          .from('marketing_campaigns')
          .delete()
          .eq('id', campaign.id);

      _loadCampaigns();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Campaign deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCampaigns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CampaignCreateScreen(),
            ),
          );
          if (result == true) {
            _loadCampaigns();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCampaigns,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No campaigns yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first marketing campaign',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final campaign = _campaigns[index];
          return _CampaignCard(
            campaign: campaign,
            onToggle: () => _toggleCampaignStatus(campaign),
            onDelete: () => _deleteCampaign(campaign),
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CampaignCreateScreen(campaign: campaign),
                ),
              );
              if (result == true) {
                _loadCampaigns();
              }
            },
          );
        },
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final MarketingCampaign campaign;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CampaignCard({
    required this.campaign,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  Color _getStatusColor() {
    switch (campaign.status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (campaign.status) {
      case 'active':
        return Icons.play_circle_filled;
      case 'paused':
        return Icons.pause_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.drafts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
                const SizedBox(width: 4),
                Text(
                  campaign.statusDisplay,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            if (campaign.totalContactCount > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: campaign.progressPercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${campaign.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Stats Row
            Row(
              children: [
                _StatChip(
                  icon: Icons.send,
                  label: '${campaign.totalSentCount} sent',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.pending,
                  label: '${campaign.pendingCount} pending',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.group,
                  label: '${campaign.totalContactCount} total',
                  color: Colors.grey,
                ),
              ],
            ),

            // Daily limit indicator
            if (campaign.isActive && campaign.dailySentCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.today, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Today: ${campaign.dailySentCount}/100',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (campaign.isDraft) ...[
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Activate'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ] else if (campaign.isActive) ...[
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ] else if (campaign.isPaused) ...[
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
