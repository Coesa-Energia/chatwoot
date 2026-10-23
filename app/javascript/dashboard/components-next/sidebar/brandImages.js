// Which image of the account's brand to show where.
//   main      the main logo (also used when only the logo is shown)
//   collapsed the image for the collapsed sidebar; falls back to the main logo
//   text      the image next to the account name: the one chosen in Settings > Account > Brand
// An empty string means "use the installation logo".
export const resolveBrandImage = (account = {}, variant = 'main') => {
  const main = account?.logo_url || '';
  const collapsed = account?.collapsed_logo_url || '';

  if (variant === 'collapsed') return collapsed || main;
  if (variant === 'text') {
    return account?.brand_text_image === 'collapsed_logo'
      ? collapsed || main
      : main;
  }
  return main;
};
