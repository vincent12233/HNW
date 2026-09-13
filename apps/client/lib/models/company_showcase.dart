class CompanyShowcase {
  const CompanyShowcase({required this.id, required this.name, required this.tagline, required this.description, this.logoUrl, this.websiteUrl, this.sector});
  final String id, name, tagline, description;
  final String? logoUrl, websiteUrl, sector;
  factory CompanyShowcase.fromJson(Map<String, dynamic> json) => CompanyShowcase(id: '${json['id'] ?? ''}', name: '${json['name'] ?? ''}', tagline: '${json['tagline'] ?? ''}', description: '${json['description'] ?? ''}', logoUrl: json['logoUrl']?.toString(), websiteUrl: json['websiteUrl']?.toString(), sector: json['sector']?.toString());
}
