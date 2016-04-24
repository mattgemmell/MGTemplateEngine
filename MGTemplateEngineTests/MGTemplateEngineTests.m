//
//  MGTemplateEngineTests.m
//  MGTemplateEngine
//
//  Created by Robert Bowdidge on 4/26/2016.
//

#import <XCTest/XCTest.h>

#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

@interface TemplateEngineTestDelegate : NSObject<MGTemplateEngineDelegate>
@property (weak, atomic) NSString *lastError;

- (void)templateEngine:(MGTemplateEngine *)engine encounteredError:(NSError *)error isContinuing:(BOOL)continuing;
@end


@interface MGTemplateEngineTest : XCTestCase {
    MGTemplateEngine *engine_;
    TemplateEngineTestDelegate *delegate_;
}

@end

@implementation TemplateEngineTestDelegate

- (void)templateEngine:(MGTemplateEngine *)engine encounteredError:(NSError *)error isContinuing:(BOOL)continuing {
    self.lastError = [error localizedDescription];
}
- (void) clearLastError {
    self.lastError = nil;
}

@end

@implementation MGTemplateEngineTest
- (void)setUp {
    engine_ = [[MGTemplateEngine alloc] init];
    // Why is this required?
    [engine_ setMatcher: [ICUTemplateMatcher matcherWithTemplateEngine: engine_]];
    delegate_ = [[TemplateEngineTestDelegate alloc] init];
    [engine_ setDelegate: delegate_];
}

- (void) tearDown {
}

- (void) testSimpleTemplate {
    NSString *result = [engine_ processTemplate: @"foo" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"foo", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo == 1 %}bah{%/if%}" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"bah", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testErrorIfTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo == 1 %}bah" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"Finished processing template, but 1 block was left open (if).", [delegate_ lastError], @"");
    XCTAssertEqualObjects(@"bah", result, @"");
}

- (void) testInvalidVariable {
    NSString *result = [engine_ processTemplate: @"{{ hello }}" withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"", result, @"");
    // XCTAssertEqualObjects(@"\"hello\" is not a valid variable", [delegate_ lastError], @"");
}

- (void) testInvalidMarker {
    NSString *result = [engine_ processTemplate: @"{%hello%}" withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"", result, @"");
    XCTAssertEqualObjects(@"\"hello\" is not a valid marker", [delegate_ lastError], @"");
}

- (void) testSimpleVariable {
    NSString *result = [engine_ processTemplate: @"{{ var }}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"hello", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleVariableNoSpaces {
    NSString *result = [engine_ processTemplate: @"{{var}}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"hello", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testUppercaseFilter {
    NSString *result = [engine_ processTemplate: @"{{var|uppercase}}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"HELLO", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testConstants {
    NSString *result = [engine_ processTemplate: @"We also know about {{ YES }} and {{ NO }} or {{ true }} and {{ false }}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"We also know about 1 and 0 or 1 and 0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testMath {
    NSString *result = [engine_ processTemplate: @"Is 1 less than 2? {% if 1 < 2 %} Yes! {% else %} No? {% /if %}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"Is 1 less than 2?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testCompareMatchingStrings {
    NSString *result = [engine_ processTemplate: @"Is x equalsstring y? {% if x equalsstring y %} Yes! {% else %} No! {% /if %}"
                                  withVariables: [NSDictionary dictionaryWithObjectsAndKeys: @"foo", @"x", @"foo", @"y", nil]];
    XCTAssertEqualObjects(@"Is x equalsstring y?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testCompareNotMatchingStrings {
    NSString *result = [engine_ processTemplate: @"Is x equalsstring y? {% if x equalsstring y %} Yes! {% else %} No! {% /if %}"
                                  withVariables: [NSDictionary dictionaryWithObjectsAndKeys: @"foo", @"x", @"bar", @"y", nil]];
    XCTAssertEqualObjects(@"Is x equalsstring y?  No! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testModByZero {
    // Ensure we don't get an arithmetic exception.
    NSString *result = [engine_ processTemplate: @"Mod by zero: {% if 1 % 0 %} shouldn't appear {% else %} didn't crash {% /if %}" withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"Mod by zero:  didn't crash ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testCompareDifferentStrings {
    NSString *result = 	result = [engine_ processTemplate: @"Is x1 equalsstring x2? {% if x1 equalsstring x2 %} Yes! {% else %} No? {% /if %}"
                                            withVariables: [NSDictionary dictionaryWithObjectsAndKeys: @"x", @"x1", @"x", @"x2", nil]];
    XCTAssertEqualObjects(@"Is x1 equalsstring x2?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testLiteral {
    NSString *result = [engine_ processTemplate: @"{% literal %}This text won't be {% now %} interpreted.{% /literal %}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"This text won't be {% now %} interpreted.", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleCountTemplate {
    NSString *result = [engine_ processTemplate: @"{{foo.@count}}" withVariables: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"1"] forKey: @"foo"]];
    XCTAssertEqualObjects(@"1", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleCountZeroTemplate {
    NSString *result = [engine_ processTemplate: @"{{foo.@count}}" withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testArrayCount {
    NSNumber *count = [[NSArray array] valueForKeyPath: @"@count"];
    XCTAssertEqual(0, [count intValue], @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountZeroTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountZeroDictTemplate {
    NSDictionary *dict = [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"myArray"] forKey: @"myKey"];
    NSString *result = [engine_ processTemplate: @"{% if myKey.myArray.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: dict];
    XCTAssertEqualObjects(@"zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testNestedIf {
    NSString *result = [engine_ processTemplate: @"{% if false %}level1{% if false %}level2{% /if %}level1{% /if %}level0"
                                  withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"level0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountNonZeroDictTemplate {
    NSDictionary *dict = [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"a"] forKey: @"myArray"] forKey: @"myKey"];
    NSString *result = [engine_ processTemplate: @"{% if myKey.myArray.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: dict];
    XCTAssertEqualObjects(@"not-zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testNestedForLoop {
    // Two items: A, B
    // A has two subitems, B has none.
    NSDictionary *subitemA1 = [NSDictionary dictionaryWithObject: @"A1" forKey: @"name"];
    NSDictionary *subitemA2 = [NSDictionary dictionaryWithObject: @"A2" forKey: @"name"];
    NSDictionary *itemA = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"A", @"name",
                              [NSArray arrayWithObjects: subitemA1, subitemA2, nil], @"subitems",
                              nil];
    NSDictionary *itemB = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"B", @"name",
                              [NSArray array], @"subitems",
                              nil];
    NSDictionary *vars = [NSDictionary dictionaryWithObject: [NSArray arrayWithObjects: itemA, itemB, nil]
                                                     forKey: @"items"];
    NSString *result = [engine_ processTemplate: @"{% for item in items %}{{item.name}}:{% for subitem in item.subitems %} subitem:{{subitem.name}} endsubitem{% /for %} enditem {% /for %}"
                                  withVariables: vars];
    
    XCTAssertEqualObjects(@"A: subitem:A1 endsubitem subitem:A2 endsubitem enditem B: enditem ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testNestedTripleForLoop {
    // Two items: A, B
    // A has two subitems, B has none.
    // One of A's subitems has a sub-sub-item.
    NSDictionary *subitemA1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"A1", @"name", [NSArray arrayWithObject: @"SP 1"], @"subsubitems", nil];
    
    NSDictionary *subitemA2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"A2", @"name",
                                [NSArray array], @"subsubitems", nil];
    NSDictionary *itemA = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"A", @"name",
                              [NSArray arrayWithObjects: subitemA1, subitemA2, nil], @"subitems",
                              nil];
    NSDictionary *itemB = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"B", @"name",
                              [NSArray array], @"subitems",
                              nil];
    NSDictionary *vars = [NSDictionary dictionaryWithObject: [NSArray arrayWithObjects: itemA, itemB, nil]
                                                     forKey: @"items"];
    NSString *result = [engine_ processTemplate: @"{% for item in items %}item:{{item.name}}{% for subitem in item.subitems %} subitem:{{subitem.name}} {% for subsubitem in subitem.subsubitems %}{{subsubitem}}{% /for %} endsubitem{%/for %} enditem {% /for %}"
                                  withVariables: vars];
    XCTAssertEqualObjects(@"item:A subitem:A1 SP 1 endsubitem subitem:A2  endsubitem enditem item:B enditem ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

// Another test to make sure the interpreter is correctly remembering state when parsing loops with no elements.
- (void) testAlernateForAndIf {
    NSDictionary *vars = [NSDictionary dictionaryWithObjectsAndKeys: [NSArray array], @"emptyArray",
                          [NSArray arrayWithObject: @"asasda"], @"itemArray", nil];
    NSString *result = [engine_ processTemplate: @"{% for i in itemArray %}{% if true %}A{% for j in emptyArray %}{% if false %}B{% /if %}C {% /for %} D {%/if%} E {% /for %}"
                                  withVariables: vars];
    XCTAssertEqualObjects(@"A D  E ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

// TODO: Test that delegate was called at the begin and end of each section.
- (void) testSection {
    NSString *result = [engine_ processTemplate: @"{%section js%}<script></script>{%/section%}{%section BODY %}Hello, World{%/section%}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"<script></script>Hello, World", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testErrorWithMissingSectionName {
    NSString *result = [engine_ processTemplate: @"{%section%}Hello, World{%/section%}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"Hello, World", result, @"");
    XCTAssertEqualObjects(@"Marker \"/section\" reported that a non-existent block ended", [delegate_ lastError], @"");
}

- (void) testDefaultIgnored {
    NSString *result = [engine_ processTemplate: @"{{value | default: bar}}"
                                  withVariables: [NSDictionary dictionaryWithObject: @"foo" forKey: @"value"]];
    XCTAssertEqualObjects(@"foo", result, @"");
    XCTAssertEqualObjects(nil, [delegate_ lastError], @"");
}

- (void) testDefaultFound {
    NSString *result = [engine_ processTemplate: @"{{value | default: bar}}"
                                  withVariables: [NSDictionary dictionaryWithObject: @"" forKey: @"value"]];
    XCTAssertEqualObjects(@"bar ", result, @"");
    XCTAssertEqualObjects(nil, [delegate_ lastError], @"");
}

- (void) testMultiWordDefaultFound {
    NSString *result = [engine_ processTemplate: @"{{value | default: 1601 Walnut St. Minneapolis}}"
                                  withVariables: [NSDictionary dictionaryWithObject: @"" forKey: @"value"]];
    XCTAssertEqualObjects(@"1601 Walnut St. Minneapolis ", result, @"");
    XCTAssertEqualObjects(nil, [delegate_ lastError], @"");
}
- (void) testDefaultWithQuotes {
    NSString *result = [engine_ processTemplate: @"{{value | default: \"1601 Walnut St. Minneapolis\"}}"
                                  withVariables: [NSDictionary dictionaryWithObject: @"" forKey: @"value"]];
    XCTAssertEqualObjects(@"1601 Walnut St. Minneapolis ", result, @"");
    XCTAssertEqualObjects(nil, [delegate_ lastError], @"");
}
@end

