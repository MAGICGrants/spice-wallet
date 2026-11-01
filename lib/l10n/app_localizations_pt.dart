// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get welcomeDescription =>
      'Uma carteira de autocustódia simples, moderna e de código aberto para Serai e as redes blockchain que Serai suporta: Bitcoin, Ethereum e Monero. Você tem controle total. Mantida pela MAGIC Grants, uma instituição de caridade pública.';

  @override
  String get welcomeGetStarted => 'Começar';

  @override
  String get welcomeAgreePrefix => 'Ao continuar, você concorda com os ';

  @override
  String get welcomeTermsLink => 'Termos de Serviço';

  @override
  String get welcomeAgreeMiddle => ' e a ';

  @override
  String get welcomePrivacyLink => 'Política de Privacidade';

  @override
  String get torChoiceSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. Você pode ativar ou desativar o Tor para cada conexão individualmente. De modo geral, como você quer que a Spice Wallet lide com as conexões Tor?';

  @override
  String connectionSetupDescription(String type) {
    return 'Informe o endereço do seu $type. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você.';
  }

  @override
  String connectionSetupDescriptionLws(String type) {
    return 'Informe o endereço do seu $type. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você. Sua chave privada de visualização e seu endereço primário serão compartilhados com este servidor.';
  }

  @override
  String get connectionProxyPortLabel => 'Porta do Proxy HTTP';

  @override
  String get connectionProxyPortHint => 'Opcional';

  @override
  String get fiatApiSetupDescription =>
      'A Spice Wallet pode buscar automaticamente os preços mais recentes dos ativos. Seus saldos não são enviados ao servidor. Como você quer buscar esses dados de preço?';

  @override
  String get createWalletDescription =>
      'Uma única frase de recuperação protege o acesso à sua carteira em todas as redes blockchain. Você quer criar uma nova carteira ou restaurar uma carteira existente?';

  @override
  String get createWalletRestoreExistingDesc => 'Qualquer frase BIP39';

  @override
  String get createWalletCreateNewDesc =>
      'A Spice Wallet gera uma frase de recuperação BIP39 de 15 palavras';

  @override
  String get generateSeedSubtitleCovered =>
      'Estas quinze palavras, nesta ordem, são a sua carteira. Anote-as e guarde-as em um cofre físico. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente. Um planejamento cuidadoso agora evita um possível desastre depois.';

  @override
  String get onboardingPasswordAcknowledge =>
      'Entendo que ninguém, incluindo a equipe da Spice Wallet, pode recuperar esta senha.';

  @override
  String get restoreWalletSubtitle => 'Qualquer frase BIP39, da Spice Wallet ou de outra carteira.';

  @override
  String get restoreScanDescription =>
      'Para alguns ativos, a Spice Wallet pode ignorar o histórico irrelevante para economizar seu tempo. Escolha o primeiro mês em que você usou a carteira ou selecione Não tenho certeza para verificar tudo. Não há problema em escolher um mês muito antigo, mas é ruim escolher um mês muito recente.';

  @override
  String get navigationBarHome => 'Início';

  @override
  String get historyFilterBlockchain => 'Rede';

  @override
  String get historyFilterAsset => 'Ativo';

  @override
  String get historyFilterRecipient => 'Destinatário';

  @override
  String get historyFilterRecipientAny => 'Qualquer Blockchain';

  @override
  String get historyFilterRecipientInvalid => 'Endereço inválido para as blockchains suportadas';

  @override
  String get historyTypeBridge => 'Ponte';

  @override
  String get historyTypeSwap => 'Troca';

  @override
  String get historyTypeAdd => 'Adicionar';

  @override
  String get historyTypeRemove => 'Remover';

  @override
  String get unlockLockedTitle => 'A Spice Wallet Está Bloqueada';

  @override
  String get unlockPasswordLabel => 'Senha da Carteira';

  @override
  String get homeNoConnection => 'Sem conexão';

  @override
  String get homeCoinNotConfigured => 'Não configurado';

  @override
  String homeUnknownCoin(String symbol) {
    return 'Moeda desconhecida: $symbol';
  }

  @override
  String homeAssetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ativos',
      one: '1 ativo',
    );
    return '$_temp0';
  }

  @override
  String get coinHomeAssetsTitle => 'Ativos';

  @override
  String get coinHomeBalancesMayBeStale =>
      'Os saldos podem estar desatualizados durante a sincronização';

  @override
  String get coinHomeAddExplorerTitle => 'Adicione um explorador para ver o histórico';

  @override
  String get coinHomeAddExplorerButton => 'Adicionar Explorador';

  @override
  String get homeTotalBalanceLabel => 'Saldo Total';

  @override
  String receiveQrHint(String coin) {
    return 'Escaneie isto da carteira remetente ou envie seu endereço $coin.';
  }

  @override
  String receiveBlockchainSubtitle(String coin) {
    return 'Blockchain $coin';
  }

  @override
  String get sendInsufficientGasError => 'Saldo de ETH insuficiente para cobrir a taxa da rede.';

  @override
  String get settingsCoinConnectionSection => 'Conexão';

  @override
  String get settingsCoinKeysSection => 'Chaves';

  @override
  String get settingsCoinConnectionSetup => 'Configuração da Conexão';

  @override
  String get settingsCoinExplorer => 'Explorador';

  @override
  String get settingsCoinNotConfigured => 'Não configurado';

  @override
  String get syncFrequencySheetSubtitle =>
      'Com que frequência suas carteiras sincronizam enquanto o app está fechado.';

  @override
  String get syncFrequencyContinuousDesc =>
      'Sincroniza suas carteiras continuamente em segundo plano para que estejam sempre atualizadas ao abrir o app. Usa mais bateria e exige uma notificação persistente.';

  @override
  String get syncFrequencyPeriodicDesc =>
      'Sincroniza suas carteiras periodicamente em segundo plano para que geralmente estejam atualizadas ao abrir o app. Um nó Monero só sincroniza enquanto carrega e no WiFi.';

  @override
  String get syncFrequencyPeriodicDescIos =>
      'Sincroniza suas carteiras periodicamente em segundo plano para que geralmente estejam atualizadas ao abrir o app. Um nó Monero só sincroniza enquanto carrega.';

  @override
  String get settingsTestnetCoinsLabel => 'Moedas Testnet';

  @override
  String get settingsTestnetCoinsDescription =>
      'Mostrar moedas testnet (ex.: Bitcoin Testnet) na lista de moedas.';

  @override
  String get settingsThemeLightDesc => 'Papel quente, o padrão';

  @override
  String get settingsSeedPhraseLabel => 'Frase de Recuperação';

  @override
  String get revealSeedSubtitleRevealed =>
      'Guarde-as em segurança. Não as compartilhe. Se você perder estas palavras ou compartilhá-las com outra pessoa, perderá seu dinheiro permanentemente.';

  @override
  String get revealSeedBackButton => 'Voltar às Configurações';

  @override
  String get revealSeedHideButton => 'Ocultar e Voltar';

  @override
  String get addressBookAddDescription => 'Um nome e ao menos um endereço para pagar essa pessoa.';

  @override
  String get addressBookEditDescription => 'Um nome e ao menos um endereço para pagar essa pessoa.';

  @override
  String get addressBookAddressesLabel => 'Endereços';

  @override
  String get addressBookAddressesNoneYet => 'nenhum ainda';

  @override
  String get addressBookAtLeastOneAddressError => 'Informe pelo menos um endereço';

  @override
  String addressBookNoContactsForCoin(String coinSymbol) {
    return 'Nenhum contato com endereço $coinSymbol';
  }

  @override
  String invalidAddressForChain(String chain) {
    return 'Endereço $chain inválido';
  }

  @override
  String get sendFromLabel => 'De';

  @override
  String get sendIrreversibleNote =>
      'As transações são irreversíveis. Você pode conferir estes detalhes novamente na próxima etapa.';

  @override
  String sendAddressHint(String coin) {
    return 'Endereço $coin';
  }

  @override
  String sendPickContactSubtitle(String coin) {
    return 'Escolha um contato com endereço $coin.';
  }

  @override
  String sendContactNoAddress(String coin) {
    return 'Sem endereço $coin';
  }

  @override
  String get torSettingsSheetSubtitle =>
      'O Tor pode ocultar seu endereço IP dos servidores aos quais você se conecta. Isso não reduz as informações que ficam armazenadas em blockchains públicas. Alterar isto reconecta todas as redes.';

  @override
  String get connectionTorUnavailable =>
      'O Tor não está disponível no momento. Verifique se ele está ativo e tente novamente.';

  @override
  String get explorerSetupTitle => 'Configuração do Explorador de Blocos';

  @override
  String get explorerSetupDescription =>
      'Opcionalmente, defina uma instância do explorador Blockscout para carregar o histórico completo de transações. Selecione apenas um servidor em que você confia. Mesmo se você usar o Tor, este servidor pode obter informações sobre você.';

  @override
  String get explorerAddressLabel => 'Endereço do Explorador';

  @override
  String get explorerRemovedMessage => 'Explorador removido.';
}
