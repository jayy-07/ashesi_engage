class Process {
  final String title;
  final String description;
  final String status;
  final String imageUrl;
  final double proposalProgress;
  final double votingProgress;
  final double implementationProgress;
  final int daysLeft;
  final String phase;

  const Process({
    required this.title,
    required this.description,
    required this.status,
    required this.imageUrl,
    required this.proposalProgress,
    required this.votingProgress,
    required this.implementationProgress,
    required this.daysLeft,
    required this.phase,
  });
}
