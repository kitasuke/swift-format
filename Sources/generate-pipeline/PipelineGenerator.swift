//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftSyntax

/// Generates the extensions to the lint and format pipelines.
final class PipelineGenerator: FileGenerator {

  /// The rules collected by scanning the formatter source code.
  let ruleCollector: RuleCollector

  /// Creates a new pipeline generator.
  init(ruleCollector: RuleCollector) {
    self.ruleCollector = ruleCollector
  }

  func write(into handle: FileHandle) throws {


    // import SwiftFormatCore
    // import SwiftFormatRules
    // import SwiftSyntax
    writeImports(to: handle)

    // extension LintPipeline {
    //   func visit(_ node: \(nodeType)) -> SyntaxVisitorContinueKind {
    //     _ = \(ruleName)(context: context).visit(node)
    //     return .visitChildren
    //   }
    writeLintPipelineExtension(to: handle)

    // extension FormatPipeline {
    //   func visit(_ node: Syntax) -> Syntax {
    //     var node = node
    //     node = \(ruleName)(context: context).visit(node)
    //     return node
    //   }
    // }
    writeFormatPipelineExtension(to: handle)
  }

  private func writeImports(to handle: FileHandle) {
    let sourceComment = """
    //===----------------------------------------------------------------------===//
    //
    // This source file is part of the Swift.org open source project
    //
    // Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
    // Licensed under Apache License v2.0 with Runtime Library Exception
    //
    // See https://swift.org/LICENSE.txt for license information
    // See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
    //
    //===----------------------------------------------------------------------===//

    // This file is automatically generated with generate-pipeline. Do Not Edit!


    """

    // import `identifier`
    let importIdentifiers = ["SwiftFormatCore", "SwiftFormatRules", "SwiftSyntax"]
    for (index, identifier) in importIdentifiers.enumerated() {
      var importDecl = makeImportDecl(identifier: identifier)
      if index == 0 {
        importDecl = importDecl.withLeadingTrivia(.lineComment(sourceComment))
      }
      handle.write(importDecl.description)
    }
  }

  private func writeLintPipelineExtension(to handle: FileHandle) {
    // func visit(_ node: `nodeType`) -> SyntaxVisitorContinueKind {
    var memberDeclList: [MemberDeclListItemSyntax] = []
    for (nodeType, lintRules) in ruleCollector.syntaxNodeLinters.sorted(by: { $0.key < $1.key }) {
      let discardAssignment = SyntaxFactory.makeDiscardAssignmentExpr(
        wildcard: SyntaxFactory.makeWildcardKeyword(
          leadingTrivia: .init(pieces: [.newlines(1), .spaces(4)]),
          trailingTrivia: .spaces(1)
        )
      )

      // _ = `ruleName`(context: context).visit(node)
      var codeBlockItems: [CodeBlockItemSyntax] = []
      for ruleName in lintRules.sorted() {
        let funcCallBlock = makeVisitFuncCallBlock(
          leftExpr: discardAssignment,
          funcName: ruleName,
          labelName: "context",
          expressionIdentifier: "context",
          memberAccessName: "visit",
          innerExpressionIdentifier: "node"
        )
        codeBlockItems.append(funcCallBlock)
      }

      // return .visitChildren
      let returnBlock = makeReturnBlock(
        dot: SyntaxFactory.makePrefixPeriodToken(),
        identifier: "visitChildren"
      )
      codeBlockItems.append(returnBlock)
      let codeBlock = SyntaxFactory.makeCodeBlock(
        leftBrace: SyntaxFactory.makeLeftBraceToken(),
        statements: SyntaxFactory.makeCodeBlockItemList(codeBlockItems),
        rightBrace: SyntaxFactory.makeRightBraceToken(leadingTrivia: .init(pieces: [.newlines(1), .spaces(2)]))
      )
      let functionDecl = makeVisitFuncDecl(
        funcName: "visit",
        secondParameterName: "node",
        parameterType: nodeType,
        returnType: "SyntaxVisitorContinueKind",
        codeBlock: codeBlock
      )
      memberDeclList.append(SyntaxFactory.makeMemberDeclListItem(
        decl: functionDecl,
        semicolon: nil
      ))
    }
    let memberDeclBlock = SyntaxFactory.makeMemberDeclBlock(
      leftBrace: SyntaxFactory.makeLeftBraceToken(),
      members: SyntaxFactory.makeMemberDeclList(memberDeclList),
      rightBrace: SyntaxFactory.makeRightBraceToken(
        leadingTrivia: .init(pieces: [.newlines(1)]),
        trailingTrivia: .newlines(1)
      )
    )
    
    // extension LintPipeline
    let extensionKeyword = SyntaxFactory.makeExtensionKeyword(
      leadingTrivia: .newlines(1),
      trailingTrivia: .spaces(1)
    )
    let extendedType = SyntaxFactory.makeTypeIdentifier(
      "LintPipeline",
      trailingTrivia: .spaces(1)
    )
    let extensionDecl = SyntaxFactory.makeExtensionDecl(
      attributes: nil,
      modifiers: nil,
      extensionKeyword: extensionKeyword,
      extendedType: extendedType,
      inheritanceClause: nil,
      genericWhereClause: nil,
      members: memberDeclBlock
    )
    handle.write(extensionDecl.description)
  }

  private func writeFormatPipelineExtension(to handle: FileHandle) {
    // var node = node
    var codeBlockItems: [CodeBlockItemSyntax] = []
    let variableBlock = makeVariableDeclBlock(identifier: "node", valueIdentifier: "node")
    codeBlockItems.append(variableBlock)

    // node = `ruleName`(context: context).visit(node)
    let nodeExpr = SyntaxFactory.makeIdentifierExpr(
      identifier: SyntaxFactory.makeIdentifier(
        "node",
        leadingTrivia: .init(pieces: [.newlines(1), .spaces(4)]),
        trailingTrivia: .spaces(1)
      ),
      declNameArguments: nil
    )
    for ruleName in ruleCollector.allFormatters.sorted() {
      let funcCallBlock = makeVisitFuncCallBlock(
        leftExpr: nodeExpr,
        funcName: ruleName,
        labelName: "context",
        expressionIdentifier: "context",
        memberAccessName: "visit",
        innerExpressionIdentifier: "node"
      )
      codeBlockItems.append(funcCallBlock)
    }

    // return node
    let returnBlock = makeReturnBlock(
      dot: nil,
      identifier: "node"
    )
    codeBlockItems.append(returnBlock)
    
    let codeBlock = SyntaxFactory.makeCodeBlock(
      leftBrace: SyntaxFactory.makeLeftBraceToken(),
      statements: SyntaxFactory.makeCodeBlockItemList(codeBlockItems),
      rightBrace: SyntaxFactory.makeRightBraceToken(leadingTrivia: .init(pieces: [.newlines(1), .spaces(2)]))
    )
    let functionDecl = makeVisitFuncDecl(
      funcName: "visit",
      secondParameterName: "node",
      parameterType: "Syntax",
      returnType: "Syntax",
      codeBlock: codeBlock
    )
    let memberDeclItem = SyntaxFactory.makeMemberDeclListItem(
      decl: functionDecl,
      semicolon: nil
    )
    let memberDeclBlock = SyntaxFactory.makeMemberDeclBlock(
      leftBrace: SyntaxFactory.makeLeftBraceToken(),
      members: SyntaxFactory.makeMemberDeclList([memberDeclItem]),
      rightBrace: SyntaxFactory.makeRightBraceToken(
        leadingTrivia: .init(pieces: [.newlines(1)]),
        trailingTrivia: .newlines(1)
      )
    )
    
    // extension FormatPipeline
    let extensionKeyword = SyntaxFactory.makeExtensionKeyword(
      leadingTrivia: .newlines(1),
      trailingTrivia: .spaces(1)
    )
    let extendedType = SyntaxFactory.makeTypeIdentifier(
      "FormatPipeline",
      trailingTrivia: .spaces(1)
    )
    let extensionDecl = SyntaxFactory.makeExtensionDecl(
      attributes: nil,
      modifiers: nil,
      extensionKeyword: extensionKeyword,
      extendedType: extendedType,
      inheritanceClause: nil,
      genericWhereClause: nil,
      members: memberDeclBlock
    )
    handle.write(extensionDecl.description)
  }

  // import `identifier`
  private func makeImportDecl(identifier: String) -> ImportDeclSyntax {
    let importKeyword = SyntaxFactory.makeImportKeyword(trailingTrivia: .spaces(1))
    let identifier = SyntaxFactory.makeIdentifier(identifier)
    let accessPathComponent = SyntaxFactory.makeAccessPathComponent(
      name: identifier,
      trailingDot: nil
    )
    let accessPath = SyntaxFactory.makeAccessPath([accessPathComponent])
    return SyntaxFactory.makeImportDecl(
      attributes: nil,
      modifiers: nil,
      importTok: importKeyword,
      importKind: nil,
      path: accessPath
    ).withTrailingTrivia(.newlines(1))
  }
    
  // func `funcName`(_ `secondParameterName`: `parameterType`) -> `returnType` {
  private func makeVisitFuncDecl(
    funcName: String,
    secondParameterName: String,
    parameterType: String,
    returnType: String,
    codeBlock: CodeBlockSyntax
  ) -> FunctionDeclSyntax {
    let funcKeyword = SyntaxFactory.makeFuncKeyword(
      leadingTrivia: .init(pieces: [.newlines(2), .spaces(2)]),
      trailingTrivia: .spaces(1)
    )
    let funcName = SyntaxFactory.makeIdentifier(funcName)
    let functionParameter = SyntaxFactory.makeFunctionParameter(
      attributes: nil,
      firstName: SyntaxFactory.makeWildcardKeyword(trailingTrivia: .spaces(1)),
      secondName: SyntaxFactory.makeIdentifier(secondParameterName),
      colon: SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1)),
      type: SyntaxFactory.makeTypeIdentifier(parameterType),
      ellipsis: nil,
      defaultArgument: nil,
      trailingComma: nil
    )
    let parameterClause = SyntaxFactory.makeParameterClause(
      leftParen: SyntaxFactory.makeLeftParenToken(),
      parameterList: SyntaxFactory.makeFunctionParameterList([functionParameter]),
      rightParen: SyntaxFactory.makeRightParenToken(trailingTrivia: .spaces(1))
    )
    let returnClause = SyntaxFactory.makeReturnClause(
      arrow: SyntaxFactory.makeArrowToken(trailingTrivia: .spaces(1)),
      returnType: SyntaxFactory.makeTypeIdentifier(returnType, trailingTrivia: .spaces(1))
    )
    let funcSignature = SyntaxFactory.makeFunctionSignature(
      input: parameterClause,
      throwsOrRethrowsKeyword: nil,
      output: returnClause
    )
    return SyntaxFactory.makeFunctionDecl(
      attributes: nil,
      modifiers: nil,
      funcKeyword: funcKeyword,
      identifier: funcName,
      genericParameterClause: nil,
      signature: funcSignature,
      genericWhereClause: nil,
      body: codeBlock
    )
  }
    
  // var `identifier` = `valueIdentifier`
  private func makeVariableDeclBlock(
    identifier: String,
    valueIdentifier: String
  ) -> CodeBlockItemSyntax {
    let varKeyword = SyntaxFactory.makeVarKeyword(
      leadingTrivia: .init(pieces: [.newlines(1), .spaces(4)]),
      trailingTrivia: .spaces(1)
    )
    let initializerClause = SyntaxFactory.makeInitializerClause(
      equal: SyntaxFactory.makeEqualToken(trailingTrivia: .spaces(1)),
      value: SyntaxFactory.makeIdentifierExpr(
        identifier: SyntaxFactory.makeIdentifier(identifier),
        declNameArguments: nil
      )
    )
    let patternBinding = SyntaxFactory.makePatternBinding(
      pattern: SyntaxFactory.makeIdentifierPattern(
        identifier: SyntaxFactory.makeIdentifier(
          identifier,
          trailingTrivia: .spaces(1)
        )
      ),
      typeAnnotation: nil,
      initializer: initializerClause,
      accessor: nil,
      trailingComma: nil
    )
    let variableDecl = SyntaxFactory.makeVariableDecl(
      attributes: nil,
      modifiers: nil,
      letOrVarKeyword: varKeyword,
      bindings: SyntaxFactory.makePatternBindingList([patternBinding]))
    return SyntaxFactory.makeCodeBlockItem(
      item: variableDecl,
      semicolon: nil,
      errorTokens: nil
    )
  }
    
  // `leftExpr` = `funcName`(context: context).visit(node)
  private func makeVisitFuncCallBlock(
    leftExpr: ExprSyntax,
    funcName: String,
    labelName: String,
    expressionIdentifier: String,
    memberAccessName: String,
    innerExpressionIdentifier: String
  ) -> CodeBlockItemSyntax {
    let assignment = SyntaxFactory.makeAssignmentExpr(assignToken: SyntaxFactory.makeEqualToken(trailingTrivia: .spaces(1)))

    let funcCallArgument = SyntaxFactory.makeFunctionCallArgument(
      label: SyntaxFactory.makeIdentifier(labelName),
      colon: SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1)),
      expression: SyntaxFactory.makeIdentifierExpr(
        identifier: SyntaxFactory.makeIdentifier(expressionIdentifier),
        declNameArguments: nil
      ),
      trailingComma: nil)
    let innerFuncCall = SyntaxFactory.makeFunctionCallExpr(
      calledExpression: SyntaxFactory.makeIdentifierExpr(
        identifier: SyntaxFactory.makeIdentifier(funcName),
        declNameArguments: nil
      ),
      leftParen: SyntaxFactory.makeLeftParenToken(),
      argumentList: SyntaxFactory.makeFunctionCallArgumentList([funcCallArgument]),
      rightParen: SyntaxFactory.makeRightParenToken(),
      trailingClosure: nil
    )
    let memberAccess = SyntaxFactory.makeMemberAccessExpr(
      base: innerFuncCall,
      dot: SyntaxFactory.makePeriodToken(),
      name: SyntaxFactory.makeIdentifier(memberAccessName),
      declNameArguments: nil)

    let innerFuncCallArgument = SyntaxFactory.makeFunctionCallArgument(
      label: nil,
      colon: nil,
      expression: SyntaxFactory.makeIdentifierExpr(
        identifier: SyntaxFactory.makeIdentifier(innerExpressionIdentifier),
        declNameArguments: nil
      ),
      trailingComma: nil
    )
    let funcCall = SyntaxFactory.makeFunctionCallExpr(
      calledExpression: memberAccess,
      leftParen: SyntaxFactory.makeLeftParenToken(),
      argumentList: SyntaxFactory.makeFunctionCallArgumentList([innerFuncCallArgument]),
      rightParen: SyntaxFactory.makeRightParenToken(),
      trailingClosure: nil)
    let sequenceExpr = SyntaxFactory.makeSequenceExpr(elements: SyntaxFactory.makeExprList([leftExpr, assignment, funcCall]))
    return SyntaxFactory.makeCodeBlockItem(
      item: sequenceExpr,
      semicolon: nil,
      errorTokens: nil
    )
  }
    
  // return `identifier`
  private func makeReturnBlock(dot: TokenSyntax?, identifier: String) -> CodeBlockItemSyntax {
    var returnExpr = SyntaxFactory.makeMemberAccessExpr(
      base: nil,
      dot: SyntaxFactory.makePrefixPeriodToken(),
      name: SyntaxFactory.makeIdentifier(identifier),
      declNameArguments: nil
    )
    if dot == nil {
      returnExpr = returnExpr.withDot(nil)
    }
    let returnStmt = SyntaxFactory.makeReturnStmt(
      returnKeyword: SyntaxFactory.makeReturnKeyword(
        leadingTrivia: .init(pieces: [.newlines(1), .spaces(4)]),
        trailingTrivia: .spaces(1)
        ),
      expression: returnExpr
    )
    return SyntaxFactory.makeCodeBlockItem(
      item: returnStmt,
      semicolon: nil,
      errorTokens: nil
    )
  }
}