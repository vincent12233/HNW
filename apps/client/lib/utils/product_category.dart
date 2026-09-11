String? portfolioCategory(String category) {
  switch (category.trim().toUpperCase()) {
    case 'INST':
    case 'INSTITUTIONAL':
    case 'LIMIT_UP':
      return 'Institutional';
    case 'OTC':
    case 'BLOCK':
    case 'BLOCK_TRADE':
      return 'OTC';
    case 'IPO':
      return 'IPO';
    default:
      return null;
  }
}
