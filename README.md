# 🚀 Cursor IDE - Script de Instalação Inteligente

Um script bash elegante e robusto para gerenciar o Cursor IDE no Linux, oferecendo uma experiência de instalação suave e interativa.

## ✨ Características

- 🎯 Instalação inteligente e interativa
- 🔄 Sistema de atualização com backup automático
- 🧹 Desinstalação segura e completa
- 🛠️ Ferramentas de reparo e manutenção
- 📊 Barra de progresso visual
- 🎨 Interface colorida e amigável
- 🔒 Sistema de backup e recuperação

## 📋 Pré-requisitos

- Sistema operacional Linux
- Bash 4.0 ou superior
- Conexão com a internet
- 500MB de espaço livre em disco
- Permissões de usuário adequadas

## 🚀 Como Usar

### Instalação Básica

```bash
./acursor.sh --install
```

### Outras Opções

```bash
./acursor.sh --help     # Mostra ajuda
./acursor.sh --repair   # Repara instalação
./acursor.sh --uninstall # Desinstala o Cursor
```

## 🎯 Funcionalidades Detalhadas

### 1. Instalação Inteligente
- Verifica instalações existentes
- Detecta espaço em disco disponível
- Testa conexão com a internet
- Cria estrutura de diretórios necessária
- Configura atalhos e integrações com o sistema

### 2. Gerenciamento de Instalações Existentes
Ao encontrar instalações existentes, oferece as seguintes opções:

- **U - Atualizar**: Atualiza uma instalação existente
  - Cria backup automático
  - Baixa nova versão
  - Sistema de rollback em caso de falha
  
- **R - Remover**: Remove uma instalação específica
  - Remove todos os arquivos associados
  - Limpa entradas do sistema
  - Atualiza cache do sistema
  
- **A - Remover Tudo**: Remove todas as instalações encontradas
  - Limpeza completa do sistema
  - Remoção de todas as versões
  
- **S - Substituir**: Mantém instalações existentes e adiciona nova
  - Instalação paralela
  - Mantém versões anteriores

### 3. Sistema de Atualização
- Download com barra de progresso
- Verificação de integridade
- Backup automático da versão atual
- Restauração automática em caso de falha
- Validação pós-download

### 4. Recursos de Segurança
- Verificação de dependências
- Validação de downloads
- Sistema de backup e restauração
- Tratamento de erros
- Logs detalhados

### 5. Interface Amigável
- 🎨 Saída colorida
- ⏳ Barras de progresso
- ✅ Indicadores de sucesso/falha
- 📝 Logs informativos
- 🔄 Status em tempo real

## 🛠️ Opções de Linha de Comando

| Opção | Descrição |
|-------|-----------|
| `-i, --install` | Instala o Cursor IDE |
| `-u, --uninstall` | Remove o Cursor IDE |
| `-r, --repair` | Repara a instalação |
| `-h, --help` | Mostra ajuda |

## 📝 Logs e Diagnóstico

O script mantém logs detalhados em:
- \`~/.cursor_log\` para logs de execução
- Mensagens coloridas no terminal
- Informações de progresso em tempo real

## 🔧 Solução de Problemas

### Espaço Insuficiente
```bash
# Verifique o espaço disponível
df -h
```

### Falha na Atualização
- O script mantém backup automático
- Restauração automática em caso de falha
- Logs detalhados para diagnóstico

### Problemas de Permissão
```bash
# Verifique as permissões
ls -l ~/.local/bin/cursor
```

## 🤝 Contribuindo

Sinta-se à vontade para:
1. Abrir issues
2. Enviar pull requests
3. Sugerir melhorias
4. Reportar bugs

## 📜 Licença

Este script é distribuído sob a licença MIT.

## ✨ Agradecimentos

- Comunidade Cursor IDE
- Contribuidores do projeto
- Usuários que fornecem feedback

---
Desenvolvido com ❤️ por Truuta 